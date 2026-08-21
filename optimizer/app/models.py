from datetime import date
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, Field


class OptimizeRequest(BaseModel):
    contract_reference: str = Field(
        min_length=1,
        examples=["DEMO-AIR-HUB1-2026"],
    )
    work_date: date
    trigger_reason: str | None = Field(
        default=None,
        examples=["Initial schedule generation"],
    )
    parent_run_id: int | None = Field(
        default=None,
        ge=1,
    )


class AssignmentResponse(BaseModel):
    employee_id: int
    employee_number: str
    full_name: str
    contract_type: Literal["PERMANENT", "CONTRACTOR"]
    shift_code: str
    time_of_day: Literal["DAY", "NIGHT"]
    assigned_hours: Decimal
    hourly_rate: Decimal
    assignment_cost: Decimal


class DemandResponse(BaseModel):
    time_of_day: Literal["DAY", "NIGHT"]
    required_hours: Decimal
    scheduled_hours: Decimal
    minimum_hours: Decimal
    maximum_hours: Decimal
    coverage_percent: Decimal
    within_tolerance: bool


class OptimizeResponse(BaseModel):
    schedule_run_id: int
    status: Literal[
        "OPTIMAL",
        "FEASIBLE",
        "INFEASIBLE",
        "MODEL_INVALID",
        "UNKNOWN",
    ]
    contract_reference: str
    work_date: date
    total_cost: Decimal | None = None
    assignments: list[AssignmentResponse] = Field(default_factory=list)
    demands: list[DemandResponse] = Field(default_factory=list)
    message: str


class StoredAssignmentResponse(BaseModel):
    employee_number: str
    full_name: str
    contract_type: Literal["PERMANENT", "CONTRACTOR"]
    shift_code: str
    time_of_day: Literal["DAY", "NIGHT"]
    work_date: date
    assigned_hours: Decimal
    hourly_rate: Decimal
    assignment_cost: Decimal
    selection_reason: str | None = None


class StoredMetricResponse(BaseModel):
    demand_date: date
    time_of_day: Literal["DAY", "NIGHT"]
    required_hours: Decimal
    scheduled_hours: Decimal
    coverage_percent: Decimal | None = None
    permanent_hours: Decimal
    contractor_hours: Decimal
    permanent_cost: Decimal
    contractor_cost: Decimal
    within_tolerance: bool
    warning: str | None = None


class ScheduleRunResponse(BaseModel):
    schedule_run_id: int
    parent_run_id: int | None = None

    status: str
    solver_status: str | None = None

    contract_reference: str
    customer_name: str
    station_code: str

    planning_from: date
    planning_to: date

    total_cost: Decimal | None = None
    execution_time_ms: int | None = None
    trigger_reason: str | None = None

    assignments: list[StoredAssignmentResponse] = Field(
        default_factory=list
    )

    metrics: list[StoredMetricResponse] = Field(
        default_factory=list
    )


class CreateAbsenceRequest(BaseModel):
    absence_code: str = Field(
        min_length=1,
        examples=["L"],
    )

    date_from: date
    date_to: date

    notes: str | None = Field(
        default=None,
        examples=["Reported sick before shift"],
    )


class CreateAbsenceResponse(BaseModel):
    absence_id: int
    employee_number: str
    absence_code: str
    date_from: date
    date_to: date
    notes: str | None = None
    message: str    