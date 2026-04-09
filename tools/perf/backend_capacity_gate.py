from __future__ import annotations

import asyncio
import json
import random
import time
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import httpx


DEFAULT_SCENARIOS = (
    "login",
    "authz",
    "users",
    "production-orders",
    "production-stats",
)


@dataclass
class ScenarioSpec:
    name: str
    method: str
    path: str
    requires_auth: bool = True
    headers: dict[str, str] = field(default_factory=dict)
    query: dict[str, str] = field(default_factory=dict)
    json_body: Any | None = None
    form_body: dict[str, str] | None = None
    success_statuses: set[int] | None = None


@dataclass
class MetricBucket:
    total: int = 0
    success: int = 0
    latencies_ms: list[float] = field(default_factory=list)
    status_counts: Counter[str] = field(default_factory=Counter)

    def record(self, *, latency_ms: float, status: str, success: bool) -> None:
        self.total += 1
        if success:
            self.success += 1
        self.latencies_ms.append(latency_ms)
        self.status_counts[status] += 1

    def to_dict(self) -> dict[str, Any]:
        success_rate = (self.success / self.total) if self.total else 0.0
        return {
            "total_requests": self.total,
            "successful_requests": self.success,
            "success_rate": success_rate,
            "error_rate": 1.0 - success_rate if self.total else 1.0,
            "p95_ms": _percentile(self.latencies_ms, 95),
            "p99_ms": _percentile(self.latencies_ms, 99),
            "status_counts": dict(sorted(self.status_counts.items())),
        }


def _percentile(values: list[float], percentile: int) -> float:
    if not values:
        return 0.0
    sorted_values = sorted(values)
    rank = max(0, min(len(sorted_values) - 1, int((len(sorted_values) - 1) * percentile / 100)))
    return round(float(sorted_values[rank]), 2)


def _normalize_base_url(raw_base_url: str) -> str:
    base_url = raw_base_url.strip().rstrip("/")
    if not base_url.startswith(("http://", "https://")):
        raise ValueError("base_url must start with http:// or https://")
    return base_url


def _builtin_scenarios() -> dict[str, ScenarioSpec]:
    return {
        "login": ScenarioSpec(
            name="login",
            method="POST",
            path="/api/v1/auth/login",
            requires_auth=False,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            success_statuses={200},
        ),
        "authz": ScenarioSpec(
            name="authz",
            method="GET",
            path="/api/v1/authz/permissions/me",
            query={"module": "user"},
        ),
        "users": ScenarioSpec(
            name="users",
            method="GET",
            path="/api/v1/users",
            query={"page": "1", "page_size": "20"},
        ),
        "production-orders": ScenarioSpec(
            name="production-orders",
            method="GET",
            path="/api/v1/production/orders",
            query={"page": "1", "page_size": "20"},
        ),
        "production-stats": ScenarioSpec(
            name="production-stats",
            method="GET",
            path="/api/v1/production/stats/overview",
        ),
    }


def _normalize_mapping(raw: Any, *, field_name: str) -> dict[str, str]:
    if raw is None:
        return {}
    if not isinstance(raw, dict):
        raise ValueError(f"{field_name} must be an object")
    return {str(key): str(value) for key, value in raw.items()}


def _normalize_success_statuses(raw: Any) -> set[int] | None:
    if raw is None:
        return None
    if not isinstance(raw, list):
        raise ValueError("success_statuses must be an array")
    statuses: set[int] = set()
    for item in raw:
        if not isinstance(item, int):
            raise ValueError("success_statuses values must be integers")
        statuses.add(item)
    return statuses


def _normalize_scenario(raw: Any) -> ScenarioSpec:
    if not isinstance(raw, dict):
        raise ValueError("scenario item must be an object")
    name = str(raw.get("name") or "").strip()
    method = str(raw.get("method") or "GET").strip().upper()
    path = str(raw.get("path") or "").strip()
    if not name:
        raise ValueError("scenario.name is required")
    if not path:
        raise ValueError(f"scenario[{name}].path is required")
    if not path.startswith("/"):
        raise ValueError(f"scenario[{name}].path must start with '/'")
    if not method:
        raise ValueError(f"scenario[{name}].method is required")
    requires_auth = bool(raw.get("requires_auth", True))
    headers = _normalize_mapping(raw.get("headers"), field_name=f"scenario[{name}].headers")
    query = _normalize_mapping(raw.get("query"), field_name=f"scenario[{name}].query")
    json_body = raw.get("json_body")
    form_body_raw = raw.get("form_body")
    form_body = (
        _normalize_mapping(form_body_raw, field_name=f"scenario[{name}].form_body")
        if form_body_raw is not None
        else None
    )
    if json_body is not None and form_body is not None:
        raise ValueError(f"scenario[{name}] cannot set both json_body and form_body")
    success_statuses = _normalize_success_statuses(raw.get("success_statuses"))
    return ScenarioSpec(
        name=name,
        method=method,
        path=path,
        requires_auth=requires_auth,
        headers=headers,
        query=query,
        json_body=json_body,
        form_body=form_body,
        success_statuses=success_statuses,
    )


def _load_scenarios_from_file(raw_path: str) -> dict[str, ScenarioSpec]:
    path = Path(raw_path).resolve()
    if not path.exists():
        raise FileNotFoundError(f"scenario config file not found: {path}")
    payload = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(payload, dict):
        raw_scenarios = payload.get("scenarios")
    else:
        raw_scenarios = payload
    if not isinstance(raw_scenarios, list):
        raise ValueError("scenario config must contain a 'scenarios' array")
    loaded: dict[str, ScenarioSpec] = {}
    for item in raw_scenarios:
        scenario = _normalize_scenario(item)
        if scenario.name in loaded:
            raise ValueError(f"duplicate scenario name in config: {scenario.name}")
        loaded[scenario.name] = scenario
    if not loaded:
        raise ValueError("scenario config has no scenario definitions")
    return loaded


def _build_scenario_registry(args) -> dict[str, ScenarioSpec]:
    registry = _builtin_scenarios()
    scenario_config_file = getattr(args, "scenario_config_file", None)
    if not scenario_config_file:
        return registry
    custom = _load_scenarios_from_file(scenario_config_file)
    overlap = sorted(name for name in custom if name in registry)
    if overlap:
        raise ValueError(
            "custom scenario names conflict with built-in scenarios: "
            + ", ".join(overlap)
        )
    registry.update(custom)
    return registry


def _parse_scenarios(raw: str, *, available: set[str]) -> list[str]:
    values = [item.strip() for item in raw.split(",") if item.strip()]
    if not values:
        raise ValueError("at least one scenario is required")
    unknown = [item for item in values if item not in available]
    if unknown:
        raise ValueError(f"unsupported scenarios: {', '.join(unknown)}")
    return values


def _load_tokens_from_file(token_file: str, token_count: int) -> list[str]:
    path = Path(token_file).resolve()
    if not path.exists():
        raise FileNotFoundError(f"token file not found: {path}")
    tokens = [
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.strip().startswith("#")
    ]
    if token_count > 0:
        tokens = tokens[:token_count]
    if not tokens:
        raise ValueError("no tokens were loaded from token file")
    return tokens


def _extract_access_token(payload: Any) -> str | None:
    if isinstance(payload, dict):
        direct = payload.get("access_token")
        if isinstance(direct, str) and direct.strip():
            return direct.strip()
        data = payload.get("data")
        if isinstance(data, dict):
            nested = data.get("access_token") or data.get("token")
            if isinstance(nested, str) and nested.strip():
                return nested.strip()
    return None


async def _login_once(
    *,
    client: httpx.AsyncClient,
    base_url: str,
    username: str,
    password: str,
) -> tuple[str | None, str, float]:
    request_start = time.perf_counter()
    try:
        response = await client.post(
            f"{base_url}/api/v1/auth/login",
            data={"username": username, "password": password},
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
        latency_ms = (time.perf_counter() - request_start) * 1000.0
        status = str(response.status_code)
        token = _extract_access_token(response.json())
        if not token:
            return None, status, latency_ms
        return token, status, latency_ms
    except Exception:
        latency_ms = (time.perf_counter() - request_start) * 1000.0
        return None, "EXC", latency_ms


async def _build_token_pool(
    *,
    clients: list[httpx.AsyncClient],
    base_url: str,
    token_count: int,
    login_user_prefix: str,
    password: str,
) -> list[str]:
    tokens: list[str] = []
    for index in range(max(1, token_count)):
        username = f"{login_user_prefix}{index + 1}"
        client = clients[index % len(clients)]
        token, _, _ = await _login_once(
            client=client,
            base_url=base_url,
            username=username,
            password=password,
        )
        if token:
            tokens.append(token)
    if not tokens:
        raise RuntimeError("failed to acquire any token from login flow")
    return tokens


async def _request_scenario(
    *,
    client: httpx.AsyncClient,
    base_url: str,
    scenario: ScenarioSpec,
    token: str | None,
) -> tuple[bool, str, float]:
    started_at = time.perf_counter()
    try:
        headers = dict(scenario.headers)
        if scenario.requires_auth:
            if not token:
                return False, "NO_TOKEN", 0.0
            headers.setdefault("Authorization", f"Bearer {token}")
        response = await client.request(
            scenario.method,
            f"{base_url}{scenario.path}",
            headers=headers,
            params=scenario.query or None,
            json=scenario.json_body,
            data=scenario.form_body,
        )
        latency_ms = (time.perf_counter() - started_at) * 1000.0
        if scenario.success_statuses is None:
            success = 200 <= response.status_code < 400
        else:
            success = response.status_code in scenario.success_statuses
        return success, str(response.status_code), latency_ms
    except Exception:
        latency_ms = (time.perf_counter() - started_at) * 1000.0
        return False, "EXC", latency_ms


async def _execute_scenario(
    *,
    scenario: str,
    scenario_registry: dict[str, ScenarioSpec],
    client: httpx.AsyncClient,
    base_url: str,
    token_pool: list[str],
    login_usernames: list[str],
    password: str,
) -> tuple[bool, str, float]:
    scenario_spec = scenario_registry.get(scenario)
    if scenario_spec is None:
        return False, "UNSUPPORTED_SCENARIO", 0.0

    if scenario == "login":
        username = random.choice(login_usernames)
        token, status, latency_ms = await _login_once(
            client=client,
            base_url=base_url,
            username=username,
            password=password,
        )
        if token and token_pool:
            token_pool[random.randrange(len(token_pool))] = token
        elif token:
            token_pool.append(token)
        return token is not None, status, latency_ms

    if scenario_spec.requires_auth and not token_pool:
        return False, "NO_TOKEN", 0.0

    token = random.choice(token_pool) if scenario_spec.requires_auth else None
    return await _request_scenario(
        client=client,
        base_url=base_url,
        scenario=scenario_spec,
        token=token,
    )


async def _run_capacity_gate(args) -> dict[str, Any]:
    base_url = _normalize_base_url(args.base_url)
    scenario_registry = _build_scenario_registry(args)
    scenarios = _parse_scenarios(args.scenarios, available=set(scenario_registry))
    if args.concurrency < 1:
        raise ValueError("concurrency must be >= 1")
    if args.duration_seconds < 1:
        raise ValueError("duration_seconds must be >= 1")
    if args.spawn_rate <= 0:
        raise ValueError("spawn_rate must be > 0")
    if args.session_pool_size < 1:
        raise ValueError("session_pool_size must be >= 1")
    if args.token_count < 1:
        raise ValueError("token_count must be >= 1")
    if args.error_rate_threshold < 0 or args.error_rate_threshold >= 1:
        raise ValueError("error_rate_threshold must be in [0, 1)")

    session_pool_size = max(args.session_pool_size, 1)
    max_connections = max(args.concurrency, session_pool_size)
    client_limits = httpx.Limits(
        max_connections=max_connections,
        max_keepalive_connections=max_connections,
    )
    timeout = httpx.Timeout(timeout=max(1.0, float(args.request_timeout_seconds)))
    clients = [
        httpx.AsyncClient(limits=client_limits, timeout=timeout)
        for _ in range(session_pool_size)
    ]

    token_pool: list[str]
    if args.token_file:
        token_pool = _load_tokens_from_file(args.token_file, args.token_count)
    else:
        token_pool = await _build_token_pool(
            clients=clients,
            base_url=base_url,
            token_count=args.token_count,
            login_user_prefix=args.login_user_prefix,
            password=args.password,
        )

    login_pool_size = max(args.session_pool_size, args.token_count)
    login_usernames = [f"{args.login_user_prefix}{index + 1}" for index in range(login_pool_size)]

    measure_bucket = MetricBucket()
    scenario_bucket: dict[str, MetricBucket] = {
        scenario: MetricBucket() for scenario in scenarios
    }
    total_bucket = MetricBucket()
    scenario_clock: dict[int, int] = {index: 0 for index in range(args.concurrency)}

    begin = time.monotonic()
    warmup_deadline = begin + max(0, args.warmup_seconds)
    stop_deadline = warmup_deadline + args.duration_seconds

    async def _worker(worker_id: int) -> None:
        client = clients[worker_id % session_pool_size]
        while time.monotonic() < stop_deadline:
            current_index = scenario_clock[worker_id]
            scenario_clock[worker_id] = current_index + 1
            scenario = scenarios[current_index % len(scenarios)]

            success, status, latency_ms = await _execute_scenario(
                scenario=scenario,
                scenario_registry=scenario_registry,
                client=client,
                base_url=base_url,
                token_pool=token_pool,
                login_usernames=login_usernames,
                password=args.password,
            )

            total_bucket.record(latency_ms=latency_ms, status=status, success=success)
            if time.monotonic() >= warmup_deadline:
                measure_bucket.record(latency_ms=latency_ms, status=status, success=success)
                scenario_bucket[scenario].record(
                    latency_ms=latency_ms,
                    status=status,
                    success=success,
                )

    tasks: list[asyncio.Task[None]] = []
    try:
        for worker_index in range(args.concurrency):
            tasks.append(asyncio.create_task(_worker(worker_index)))
            if worker_index < args.concurrency - 1:
                await asyncio.sleep(1.0 / args.spawn_rate)
        await asyncio.gather(*tasks)
    finally:
        await asyncio.gather(*(client.aclose() for client in clients), return_exceptions=True)

    measured = measure_bucket.to_dict()
    threshold_pass = (
        measured["p95_ms"] <= args.p95_ms
        and measured["error_rate"] <= args.error_rate_threshold
    )

    return {
        "base_url": base_url,
        "scenarios": scenarios,
        "duration_seconds": args.duration_seconds,
        "warmup_seconds": args.warmup_seconds,
        "concurrency": args.concurrency,
        "spawn_rate": args.spawn_rate,
        "token_count": len(token_pool),
        "session_pool_size": session_pool_size,
        "threshold": {
            "p95_ms": args.p95_ms,
            "error_rate_threshold": args.error_rate_threshold,
        },
        "overall": measured,
        "overall_with_warmup": total_bucket.to_dict(),
        "scenarios_metrics": {
            name: bucket.to_dict() for name, bucket in scenario_bucket.items()
        },
        "gate_passed": threshold_pass,
    }


def run_backend_capacity_gate(args) -> int:
    try:
        result = asyncio.run(_run_capacity_gate(args))
    except Exception as error:
        print(f"backend-capacity-gate failed: {error}")
        return 2

    if args.output_json:
        output_path = Path(args.output_json).resolve()
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(
            json.dumps(result, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["gate_passed"] else 1
