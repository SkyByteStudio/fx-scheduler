from __future__ import annotations

from datetime import date
from typing import Any

from app.database import get_connection


def create_employee_absence(
    *,
    employee_number: str,
    absence_code: str,
    date_from: date,
    date_to: date,
    notes: str | None,
) -> dict[str, Any]:
    if date_to < date_from:
        raise ValueError(
            "date_to cannot be earlier than date_from."
        )

    normalized_employee_number = employee_number.strip()
    normalized_absence_code = absence_code.strip().upper()

    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT
                    id,
                    employee_number,
                    active
                FROM scheduler.employees
                WHERE employee_number = %s
                """,
                (normalized_employee_number,),
            )

            employee = cursor.fetchone()

            if employee is None:
                raise ValueError(
                    f"Employee {normalized_employee_number} was not found."
                )

            if not employee["active"]:
                raise ValueError(
                    f"Employee {normalized_employee_number} is inactive."
                )

            cursor.execute(
                """
                SELECT
                    id,
                    code,
                    name,
                    blocks_work,
                    active
                FROM scheduler.absence_codes
                WHERE code = %s
                """,
                (normalized_absence_code,),
            )

            absence = cursor.fetchone()

            if absence is None:
                raise ValueError(
                    f"Absence code {normalized_absence_code} was not found."
                )

            if not absence["active"]:
                raise ValueError(
                    f"Absence code {normalized_absence_code} is inactive."
                )

            cursor.execute(
                """
                SELECT
                    ea.id,
                    ac.code,
                    ea.date_from,
                    ea.date_to
                FROM scheduler.employee_absences ea
                JOIN scheduler.absence_codes ac
                    ON ac.id = ea.absence_code_id
                WHERE ea.employee_id = %s
                  AND daterange(
                        ea.date_from,
                        ea.date_to,
                        '[]'
                      )
                      &&
                      daterange(
                        %s,
                        %s,
                        '[]'
                      )
                ORDER BY ea.date_from
                LIMIT 1
                """,
                (
                    employee["id"],
                    date_from,
                    date_to,
                ),
            )

            overlapping_absence = cursor.fetchone()

            if overlapping_absence is not None:
                raise ValueError(
                    "Employee already has an overlapping absence: "
                    f"{overlapping_absence['code']} "
                    f"from {overlapping_absence['date_from']} "
                    f"to {overlapping_absence['date_to']}."
                )

            cursor.execute(
                """
                INSERT INTO scheduler.employee_absences
                (
                    employee_id,
                    absence_code_id,
                    date_from,
                    date_to,
                    notes
                )
                VALUES
                (
                    %s,
                    %s,
                    %s,
                    %s,
                    %s
                )
                RETURNING id
                """,
                (
                    employee["id"],
                    absence["id"],
                    date_from,
                    date_to,
                    notes,
                ),
            )

            created = cursor.fetchone()

            if created is None:
                raise RuntimeError(
                    "Failed to create employee absence."
                )

    return {
        "absence_id": int(created["id"]),
        "employee_number": normalized_employee_number,
        "absence_code": normalized_absence_code,
        "date_from": date_from,
        "date_to": date_to,
        "notes": notes,
        "message": "Employee absence created successfully.",
    }