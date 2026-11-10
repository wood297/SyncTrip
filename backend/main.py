"""Run from the repository root: python -m uvicorn backend.main:app --reload."""
import logging

from botocore.exceptions import BotoCoreError, ClientError
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from pydantic import ValidationError

from backend.routes.trips import router
from backend.routes.activities import router as activities_router
from backend.services.activities import ActivityError
from backend.services.trips import TripNotFound

logger = logging.getLogger(__name__)
app = FastAPI(title="SyncTrip API", version="0.1.0")
app.include_router(router)
app.include_router(activities_router)


@app.exception_handler(ActivityError)
async def activity_error(request: Request, error: ActivityError):
    return JSONResponse(status_code=error.status_code, content={"detail": error.detail})


@app.get("/health", tags=["health"])
def health():
    """Liveness only; does not claim database connectivity."""
    return {"status": "ok"}


@app.exception_handler(TripNotFound)
async def not_found(request: Request, error: TripNotFound):
    return JSONResponse(status_code=404, content={"detail": "Trip not found"})


@app.exception_handler(BotoCoreError)
@app.exception_handler(ClientError)
async def database_error(request: Request, error: Exception):
    logger.warning("DynamoDB request failed (%s)", type(error).__name__)
    return JSONResponse(status_code=503, content={"detail": "Database unavailable"})


@app.exception_handler(ValidationError)
async def invalid_record(request: Request, error: ValidationError):
    logger.error("Stored trip does not match the response schema")
    return JSONResponse(status_code=500, content={"detail": "Invalid stored trip"})
