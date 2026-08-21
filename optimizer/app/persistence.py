from __future__ import annotations

from datetime import date
from decimal import Decimal
from typing import Any

from psycopg import Connection


def create_schedule_run(
    connection: Connection,
    *,
    contract_id: int,
    station_id: int,
    planning_date: date,
    trigger_reason: str | None = None,
    parent_run_id: int | None = None,
) -> int:
    with connection.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO scheduler.schedule_runs
            (
                parent_run_id,
                contract_id,
                station_id,
                planning_from,
                planning_to,
                status,
                trigger_reason,
                started_at
            )
            VALUES
            (
                %s,
                %s,
                %s,
                %s,
                %s,
                'RUNNING',
                %s,
                CURRENT_TIMESTAMP
            )
            RETURNING id
            """,
            (
                parent_run_id,
                contract_id,
                station_id,
                planning_date,
                planning_date,
                trigger_reason,
            ),
        )

        row = cursor.fetchone()
        if row is None:
            raise RuntimeError("Failed to create schedule run.")

        return int(row["id"])


def complete_schedule_run(
    connection: Connection,
    *,
    schedule_run_id: int,
    status: str,
    solver_status: str,
    total_cost: Decimal | None,
    execution_time_ms: int,
) -> None:
    with connection.cursor() as cursor:
        cursor.execute(
            """
            UPDATE scheduler.schedule_runs
            SET
                status = %s,
                solver_status = %s,
                total_cost = %s,
                execution_time_ms = %s,
                completed_at = CURRENT_TIMESTAMP
            WHERE id = %s
            """,
            (
                status,
                solver_status,
                total_cost,
                execution_time_ms,
                schedule_run_id,
            ),
        )

        if cursor.rowcount != 1:
            raise RuntimeError(
                f"Schedule run {schedule_run_id} was not found."
            )


def save_assignments(
    connection: Connection,
    *,
    schedule_run_id: int,
    contract_id: int,
    station_id: int,
    work_date: date,
    assignments: list[dict[str, Any]],
) -> None:
    if not assignments:
        return

    rows = [
        (
            schedule_run_id,
            assignment["employee_id"],
            contract_id,
            station_id,
            assignment["shift_id"],
            work_date,
            assignment["assigned_hours"],
            assignment["hourly_rate"],
            assignment["assignment_cost"],
            assignment["selection_reason"],
        )
        for assignment in assignments
    ]

    with connection.cursor() as cursor:
        cursor.executemany(
            """
            INSERT INTO scheduler.schedule_assignments
            (
                schedule_run_id,
                employee_id,
                contract_id,
                station_id,
                shift_id,
                work_date,
                assigned_hours,
                hourly_rate,
                assignment_cost,
                selection_reason
            )
            VALUES
            (
                %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s
            )
            """,
            rows,
        )


def save_metrics(
    connection: Connection,
    *,
    schedule_run_id: int,
    metrics: list[dict[str, Any]],
) -> None:
    if not metrics:
        return

    rows = [
        (
            schedule_run_id,
            metric["demand_date"],
            metric["time_of_day"],
            metric["required_hours"],
            metric["scheduled_hours"],
            metric["coverage_percent"],
            metric["permanent_hours"],
            metric["contractor_hours"],
            metric["permanent_cost"],
            metric["contractor_cost"],
            metric["within_tolerance"],
            metric.get("warning"),
        )
        for metric in metrics
    ]

    with connection.cursor() as cursor:
        cursor.executemany(
            """
            INSERT INTO scheduler.schedule_run_metrics
            (
                schedule_run_id,
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
            )
            VALUES
            (
                %s, %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s, %s
            )
            """,
            rows,
        )
