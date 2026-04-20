from pydantic import BaseModel


class SystemTimeSnapshot(BaseModel):
    server_utc_iso: str
    server_timezone_offset_minutes: int
    sampled_at_epoch_ms: int
