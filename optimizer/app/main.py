import logging

from fastapi import FastAPI, HTTPException

from app.models import (
    CreateAbsenceRequest,
    CreateAbsenceResponse,
    OptimizeRequest,
    OptimizeResponse,
    ScheduleRunResponse,
)
from app.queries import get_schedule_run
from app.optimizer import solve_schedule
from app.absences import create_employee_absence

logger = logging.getLogger(__name__)

app = FastAPI(
    title="Aviation Workforce Scheduler Optimizer",
    version="0.2.0",
    description=(
        "Deterministic workforce scheduling API using "
        "PostgreSQL eligibility rules and Google OR-Tools."
    ),
)


@app.get("/health")
def health() -> dict[str, str]:
    return {
        "status": "ok",
        "service": "optimizer",
    }

@app.get(
    "/runs/{schedule_run_id}",
    response_model=ScheduleRunResponse,
)
def read_schedule_run(
    schedule_run_id: int,
) -> ScheduleRunResponse:
    if schedule_run_id < 1:
        raise HTTPException(
            status_code=400,
            detail="schedule_run_id must be greater than zero.",
        )

    try:
        result = get_schedule_run(schedule_run_id)

        if result is None:
            raise HTTPException(
                status_code=404,
                detail="Schedule run was not found.",
            )

        return ScheduleRunResponse(**result)

    except HTTPException:
        raise

    except Exception as exc:
        logger.exception(
            "Failed to retrieve schedule run %s",
            schedule_run_id,
        )

        raise HTTPException(
            status_code=500,
            detail=f"Unexpected schedule retrieval error: {exc}",
        ) from exc


@app.post(
    "/optimize",
    response_model=OptimizeResponse,
)
def optimize(request: OptimizeRequest) -> OptimizeResponse:
    try:
        result = solve_schedule(
            contract_reference=request.contract_reference,
            work_date=request.work_date,
            trigger_reason=request.trigger_reason,
            parent_run_id=request.parent_run_id,
        )

        return OptimizeResponse(**result)

    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc),
        ) from exc

    except Exception as exc:
        logger.exception("Unexpected optimizer error")
        raise HTTPException(
            status_code=500,
            detail=f"Unexpected optimizer error: {exc}",
        ) from exc

@app.post(
    "/employees/{employee_number}/absences",
    response_model=CreateAbsenceResponse,
)
def add_employee_absence(
    employee_number: str,
    request: CreateAbsenceRequest,
) -> CreateAbsenceResponse:
    try:
        result = create_employee_absence(
            employee_number=employee_number,
            absence_code=request.absence_code,
            date_from=request.date_from,
            date_to=request.date_to,
            notes=request.notes,
        )

        return CreateAbsenceResponse(**result)

    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc),
        ) from exc

    except Exception as exc:
        logger.exception(
            "Failed to create absence for employee %s",
            employee_number,
        )

        raise HTTPException(
            status_code=500,
            detail=f"Unexpected absence creation error: {exc}",
        ) from exc
