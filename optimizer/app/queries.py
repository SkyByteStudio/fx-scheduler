from typing import Any

from app.database import get_connection


def get_schedule_run(schedule_run_id: int) -> dict[str, Any] | None:
    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT
                    sr.id AS schedule_run_id,
                    sr.parent_run_id,
                    sr.status,
                    sr.solver_status,
                    sr.planning_from,
                    sr.planning_to,
                    sr.total_cost,
                    sr.execution_time_ms,
                    sr.trigger_reason,

                    cc.contract_reference,
                    cc.customer_name,
                    s.code AS station_code

                FROM scheduler.schedule_runs sr

                JOIN scheduler.customer_contracts cc
                    ON cc.id = sr.contract_id

                JOIN scheduler.stations s
                    ON s.id = sr.station_id

                WHERE sr.id = %s
                """,
                (schedule_run_id,),
            )

            run = cursor.fetchone()

            if run is None:
                return None

            cursor.execute(
                """
                SELECT
                    e.employee_number,
                    CONCAT_WS(
                        ' ',
                        e.first_name,
                        e.last_name
                    ) AS full_name,
                    e.contract_type,

                    sh.shift_code,
                    sh.time_of_day,

                    sa.work_date,
                    sa.assigned_hours,
                    sa.hourly_rate,
                    sa.assignment_cost,
                    sa.selection_reason

                FROM scheduler.schedule_assignments sa

                JOIN scheduler.employees e
                    ON e.id = sa.employee_id

                JOIN scheduler.shifts sh
                    ON sh.id = sa.shift_id

                WHERE sa.schedule_run_id = %s

                ORDER BY
                    sa.work_date,
                    CASE
                        WHEN sh.time_of_day = 'DAY' THEN 1
                        WHEN sh.time_of_day = 'NIGHT' THEN 2
                        ELSE 99
                    END,
                    CASE
                        WHEN e.contract_type = 'PERMANENT' THEN 1
                        WHEN e.contract_type = 'CONTRACTOR' THEN 2
                        ELSE 99
                    END,
                    sa.hourly_rate,
                    e.employee_number
                """,
                (schedule_run_id,),
            )

            assignments = cursor.fetchall()

            cursor.execute(
                """
                SELECT
                    demand_date,
                    time_of_day,
                    required_hours,
                    scheduled_hours,
                    coverage_percent,
                    permanent_hours,
                    contractor_hours,
                    permanent_cost,
                    contractor_cost,
                    within_tolerance,
                    warning

                FROM scheduler.schedule_run_metrics

                WHERE schedule_run_id = %s

                ORDER BY
                    demand_date,
                    CASE
                        WHEN time_of_day = 'DAY' THEN 1
                        WHEN time_of_day = 'NIGHT' THEN 2
                        ELSE 99
                    END
                """,
                (schedule_run_id,),
            )

            metrics = cursor.fetchall()

    return {
        **run,
        "assignments": assignments,
        "metrics": metrics,
    }