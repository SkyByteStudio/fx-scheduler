from __future__ import annotations

from collections import defaultdict
from datetime import date
from decimal import Decimal, ROUND_HALF_UP
from time import perf_counter
from typing import Any

from ortools.sat.python import cp_model
from psycopg import Connection

from app.database import get_connection
from app.persistence import (
    complete_schedule_run,
    create_schedule_run,
    save_assignments,
    save_metrics,
)


PERMANENT_PENALTY = 0
CONTRACTOR_PENALTY = 10_000_000


def decimal_to_int(
    value: Decimal,
    multiplier: int = 100,
) -> int:
    return int(
        (value * multiplier).quantize(
            Decimal("1"),
            rounding=ROUND_HALF_UP,
        )
    )


def load_problem(
    connection: Connection,
    contract_reference: str,
    work_date: date,
) -> dict[str, Any]:
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                cc.id AS contract_id,
                cc.contract_reference,
                cc.station_id,
                s.code AS station_code
            FROM scheduler.customer_contracts cc
            JOIN scheduler.stations s
                ON s.id = cc.station_id
            WHERE cc.contract_reference = %s
              AND cc.active = TRUE
              AND %s BETWEEN cc.valid_from AND cc.valid_to
            """,
            (contract_reference, work_date),
        )

        contract = cursor.fetchone()

        if contract is None:
            raise ValueError(
                "Active customer contract was not found "
                "for the requested date."
            )

        cursor.execute(
            """
            SELECT
                cd.id AS demand_id,
                cd.time_of_day,
                cd.required_hours,
                cd.tolerance_percent,
                sh.id AS shift_id,
                sh.shift_code,
                sh.work_hours
            FROM scheduler.contract_demands cd
            JOIN scheduler.shifts sh
                ON sh.time_of_day = cd.time_of_day
               AND sh.active = TRUE
            WHERE cd.contract_id = %s
              AND cd.demand_date = %s
            ORDER BY cd.time_of_day, sh.shift_code
            """,
            (contract["contract_id"], work_date),
        )

        demands = cursor.fetchall()

        if not demands:
            raise ValueError(
                "No contract demand exists for the requested date."
            )

        cursor.execute(
            """
            SELECT DISTINCT
                ge.employee_id,
                ge.employee_number,
                ge.full_name,
                ge.employee_position,
                ge.contract_type,
                ge.hourly_rate
            FROM scheduler.contract_demands cd
            CROSS JOIN LATERAL
                scheduler.get_employee_eligibility(
                    cd.contract_id,
                    cd.demand_date,
                    cd.time_of_day
                ) ge
            WHERE cd.contract_id = %s
              AND cd.demand_date = %s
              AND ge.eligible = TRUE
            ORDER BY
                ge.contract_type,
                ge.hourly_rate,
                ge.employee_number
            """,
            (contract["contract_id"], work_date),
        )

        employees = cursor.fetchall()

    return {
        "contract": contract,
        "demands": demands,
        "employees": employees,
    }


def solve_schedule(
    contract_reference: str,
    work_date: date,
    trigger_reason: str | None = None,
    parent_run_id: int | None = None,
) -> dict[str, Any]:
    started = perf_counter()

    with get_connection() as connection:
        problem = load_problem(
            connection=connection,
            contract_reference=contract_reference,
            work_date=work_date,
        )

        contract = problem["contract"]
        employees = problem["employees"]
        demands = problem["demands"]

        schedule_run_id = create_schedule_run(
            connection,
            contract_id=contract["contract_id"],
            station_id=contract["station_id"],
            planning_date=work_date,
            trigger_reason=trigger_reason,
            parent_run_id=parent_run_id,
        )

        model = cp_model.CpModel()
        assignment_variables: dict[tuple[int, int], cp_model.IntVar] = {}

        for employee_index, employee in enumerate(employees):
            for demand_index, demand in enumerate(demands):
                variable_name = (
                    f"assign_{employee['employee_number']}_"
                    f"{demand['shift_code']}"
                )
                assignment_variables[(employee_index, demand_index)] = (
                    model.new_bool_var(variable_name)
                )

        # One employee may work at most one shift on the selected date.
        for employee_index in range(len(employees)):
            model.add(
                sum(
                    assignment_variables[(employee_index, demand_index)]
                    for demand_index in range(len(demands))
                )
                <= 1
            )

        demand_bounds: list[dict[str, Any]] = []

        for demand_index, demand in enumerate(demands):
            required_minutes = decimal_to_int(
                Decimal(demand["required_hours"]),
                multiplier=60,
            )

            tolerance = (
                Decimal(demand["tolerance_percent"])
                / Decimal("100")
            )

            minimum_minutes = int(
                (
                    Decimal(required_minutes)
                    * (Decimal("1") - tolerance)
                ).to_integral_value(rounding=ROUND_HALF_UP)
            )

            maximum_minutes = int(
                (
                    Decimal(required_minutes)
                    * (Decimal("1") + tolerance)
                ).to_integral_value(rounding=ROUND_HALF_UP)
            )

            shift_minutes = decimal_to_int(
                Decimal(demand["work_hours"]),
                multiplier=60,
            )

            scheduled_minutes = sum(
                assignment_variables[(employee_index, demand_index)]
                * shift_minutes
                for employee_index in range(len(employees))
            )

            model.add(scheduled_minutes >= minimum_minutes)
            model.add(scheduled_minutes <= maximum_minutes)

            demand_bounds.append(
                {
                    "minimum_minutes": minimum_minutes,
                    "maximum_minutes": maximum_minutes,
                    "shift_minutes": shift_minutes,
                }
            )

        objective_terms = []

        for employee_index, employee in enumerate(employees):
            employee_penalty = (
                PERMANENT_PENALTY
                if employee["contract_type"] == "PERMANENT"
                else CONTRACTOR_PENALTY
            )

            for demand_index, demand in enumerate(demands):
                assignment_cost_cents = decimal_to_int(
                    Decimal(employee["hourly_rate"])
                    * Decimal(demand["work_hours"]),
                    multiplier=100,
                )

                objective_terms.append(
                    assignment_variables[(employee_index, demand_index)]
                    * (
                        employee_penalty
                        + assignment_cost_cents
                    )
                )

        model.minimize(sum(objective_terms))

        solver = cp_model.CpSolver()
        solver.parameters.max_time_in_seconds = 15.0
        solver.parameters.num_search_workers = 4

        solver_status = solver.solve(model)
        solver_status_name = solver.status_name(solver_status)

        execution_time_ms = int(
            (perf_counter() - started) * 1000
        )

        if solver_status not in (
            cp_model.OPTIMAL,
            cp_model.FEASIBLE,
        ):
            database_status = (
                "INFEASIBLE"
                if solver_status == cp_model.INFEASIBLE
                else "FAILED"
            )

            complete_schedule_run(
                connection,
                schedule_run_id=schedule_run_id,
                status=database_status,
                solver_status=solver_status_name,
                total_cost=None,
                execution_time_ms=execution_time_ms,
            )

            return {
                "schedule_run_id": schedule_run_id,
                "status": solver_status_name,
                "contract_reference": contract_reference,
                "work_date": work_date,
                "total_cost": None,
                "assignments": [],
                "demands": [],
                "message": (
                    "No valid schedule satisfies all demand "
                    "and eligibility constraints."
                ),
            }

        assignments: list[dict[str, Any]] = []
        total_cost = Decimal("0")

        scheduled_by_time = defaultdict(
            lambda: {
                "hours": Decimal("0"),
                "permanent_hours": Decimal("0"),
                "contractor_hours": Decimal("0"),
                "permanent_cost": Decimal("0"),
                "contractor_cost": Decimal("0"),
            }
        )

        for employee_index, employee in enumerate(employees):
            for demand_index, demand in enumerate(demands):
                variable = assignment_variables[
                    (employee_index, demand_index)
                ]

                if solver.value(variable) != 1:
                    continue

                assigned_hours = Decimal(demand["work_hours"])
                hourly_rate = Decimal(employee["hourly_rate"])
                assignment_cost = assigned_hours * hourly_rate

                totals = scheduled_by_time[demand["time_of_day"]]
                totals["hours"] += assigned_hours
                total_cost += assignment_cost

                if employee["contract_type"] == "PERMANENT":
                    totals["permanent_hours"] += assigned_hours
                    totals["permanent_cost"] += assignment_cost
                    selection_reason = (
                        "Eligible permanent employee selected "
                        "before contractors"
                    )
                else:
                    totals["contractor_hours"] += assigned_hours
                    totals["contractor_cost"] += assignment_cost
                    selection_reason = (
                        "Eligible contractor selected based on "
                        "required coverage and cost"
                    )

                assignments.append(
                    {
                        "employee_id": employee["employee_id"],
                        "employee_number": employee["employee_number"],
                        "full_name": employee["full_name"],
                        "contract_type": employee["contract_type"],
                        "shift_id": demand["shift_id"],
                        "shift_code": demand["shift_code"],
                        "time_of_day": demand["time_of_day"],
                        "assigned_hours": assigned_hours,
                        "hourly_rate": hourly_rate,
                        "assignment_cost": assignment_cost,
                        "selection_reason": selection_reason,
                    }
                )

        demand_results: list[dict[str, Any]] = []
        metric_rows: list[dict[str, Any]] = []

        for demand_index, demand in enumerate(demands):
            bounds = demand_bounds[demand_index]
            totals = scheduled_by_time[demand["time_of_day"]]

            required_hours = Decimal(demand["required_hours"])
            scheduled_hours = totals["hours"]

            minimum_hours = (
                Decimal(bounds["minimum_minutes"])
                / Decimal("60")
            )
            maximum_hours = (
                Decimal(bounds["maximum_minutes"])
                / Decimal("60")
            )

            coverage_percent = (
                scheduled_hours
                / required_hours
                * Decimal("100")
                if required_hours > 0
                else Decimal("100")
            )

            within_tolerance = (
                minimum_hours
                <= scheduled_hours
                <= maximum_hours
            )

            demand_results.append(
                {
                    "time_of_day": demand["time_of_day"],
                    "required_hours": required_hours,
                    "scheduled_hours": scheduled_hours,
                    "minimum_hours": minimum_hours,
                    "maximum_hours": maximum_hours,
                    "coverage_percent": coverage_percent,
                    "within_tolerance": within_tolerance,
                }
            )

            metric_rows.append(
                {
                    "demand_date": work_date,
                    "time_of_day": demand["time_of_day"],
                    "required_hours": required_hours,
                    "scheduled_hours": scheduled_hours,
                    "coverage_percent": coverage_percent,
                    "permanent_hours": totals["permanent_hours"],
                    "contractor_hours": totals["contractor_hours"],
                    "permanent_cost": totals["permanent_cost"],
                    "contractor_cost": totals["contractor_cost"],
                    "within_tolerance": within_tolerance,
                    "warning": (
                        None
                        if within_tolerance
                        else "Coverage is outside tolerance."
                    ),
                }
            )

        assignments.sort(
            key=lambda item: (
                item["time_of_day"],
                item["contract_type"] != "PERMANENT",
                item["hourly_rate"],
                item["employee_number"],
            )
        )

        save_assignments(
            connection,
            schedule_run_id=schedule_run_id,
            contract_id=contract["contract_id"],
            station_id=contract["station_id"],
            work_date=work_date,
            assignments=assignments,
        )

        save_metrics(
            connection,
            schedule_run_id=schedule_run_id,
            metrics=metric_rows,
        )

        complete_schedule_run(
            connection,
            schedule_run_id=schedule_run_id,
            status="COMPLETED",
            solver_status=solver_status_name,
            total_cost=total_cost,
            execution_time_ms=execution_time_ms,
        )

        return {
            "schedule_run_id": schedule_run_id,
            "status": solver_status_name,
            "contract_reference": contract_reference,
            "work_date": work_date,
            "total_cost": total_cost,
            "assignments": assignments,
            "demands": demand_results,
            "message": "Schedule generated and persisted successfully.",
        }
