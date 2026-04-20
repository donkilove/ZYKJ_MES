from datetime import UTC, datetime

from fastapi import APIRouter

from app.schemas.common import ApiResponse, success_response
from app.schemas.system import SystemTimeSnapshot


router = APIRouter()


@router.get("/time", response_model=ApiResponse[SystemTimeSnapshot])
def get_system_time() -> ApiResponse[SystemTimeSnapshot]:
    now_utc = datetime.now(UTC)
    local_offset = datetime.now().astimezone().utcoffset()
    offset_minutes = int((local_offset.total_seconds() if local_offset else 0) // 60)
    payload = SystemTimeSnapshot(
        server_utc_iso=now_utc.isoformat().replace("+00:00", "Z"),
        server_timezone_offset_minutes=offset_minutes,
        sampled_at_epoch_ms=int(now_utc.timestamp() * 1000),
    )
    return success_response(payload)
