#!/usr/bin/env python3
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from typing import Optional, Dict, Any, Tuple

AUTH_PATH = os.path.expanduser("~/.codex/auth.json")
USAGE_URL = "https://chatgpt.com/backend-api/wham/usage"
TOKEN_URL = "https://auth.openai.com/oauth/token"
CLIENT_ID = "app_EMoamEEZ73f0CkXaXp7hrann"
REFRESH_AGE_MS = 8 * 24 * 60 * 60 * 1000


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def read_json(path: str) -> dict:
    if not os.path.exists(path):
        fail("Codex auth not found. Run `codex` to log in.")
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except Exception:
        fail("Failed to read Codex auth file.")
    return {}


def write_json(path: str, payload: dict) -> None:
    try:
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2)
    except Exception:
        pass


def request_json(
    url: str,
    method: str,
    headers: dict,
    body: Optional[bytes],
    timeout: int = 15
) -> Tuple[int, Dict[str, Any], Dict[str, Any]]:
    req = urllib.request.Request(url, data=body, method=method)
    for key, value in headers.items():
        req.add_header(key, value)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            status = resp.getcode()
            raw = resp.read().decode("utf-8")
            payload = json.loads(raw) if raw else {}
            return status, payload, dict(resp.headers)
    except Exception as exc:
        fail(f"Request failed: {exc}")
    return 0, {}, {}


def needs_refresh(auth: dict) -> bool:
    last_refresh = auth.get("last_refresh")
    if not isinstance(last_refresh, str):
        return True
    try:
        last_ms = int(datetime.fromisoformat(last_refresh.replace("Z", "+00:00")).timestamp() * 1000)
    except Exception:
        return True
    return (int(time.time() * 1000) - last_ms) > REFRESH_AGE_MS


def refresh_token(auth: dict) -> Optional[str]:
    tokens = auth.get("tokens") if isinstance(auth.get("tokens"), dict) else None
    if not tokens:
        return None
    refresh = tokens.get("refresh_token")
    if not isinstance(refresh, str) or not refresh.strip():
        return None

    body = urllib.parse.urlencode({
        "grant_type": "refresh_token",
        "client_id": CLIENT_ID,
        "refresh_token": refresh,
    }).encode("utf-8")

    status, payload, _ = request_json(
        TOKEN_URL,
        "POST",
        {"Content-Type": "application/x-www-form-urlencoded"},
        body,
        timeout=15,
    )

    if status >= 400:
        return None

    access = payload.get("access_token")
    if not isinstance(access, str) or not access.strip():
        return None

    tokens["access_token"] = access
    if isinstance(payload.get("refresh_token"), str):
        tokens["refresh_token"] = payload.get("refresh_token")
    if isinstance(payload.get("id_token"), str):
        tokens["id_token"] = payload.get("id_token")
    auth["tokens"] = tokens
    auth["last_refresh"] = datetime.now(timezone.utc).isoformat()
    write_json(AUTH_PATH, auth)
    return access


def fetch_usage(token: str, account_id: Optional[str]) -> Tuple[dict, dict]:
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
        "User-Agent": "MenuUsage",
    }
    if account_id:
        headers["ChatGPT-Account-Id"] = account_id
    status, payload, resp_headers = request_json(USAGE_URL, "GET", headers, None, timeout=10)
    if status < 200 or status >= 300:
        fail(f"Usage request failed (HTTP {status}).")
    return payload, resp_headers


def read_number(value) -> Optional[float]:
    try:
        num = float(value)
        if num != num:
            return None
        return num
    except Exception:
        return None


def reset_from_window(window: Optional[dict]) -> Optional[str]:
    if not isinstance(window, dict):
        return None
    if isinstance(window.get("reset_at"), (int, float)):
        return datetime.fromtimestamp(float(window["reset_at"]), tz=timezone.utc).isoformat()
    return None


def main() -> None:
    auth = read_json(AUTH_PATH)
    tokens = auth.get("tokens") if isinstance(auth.get("tokens"), dict) else None
    if not tokens:
        fail("Codex tokens missing. Run `codex` to log in.")

    access = tokens.get("access_token")
    if not isinstance(access, str) or not access.strip():
        fail("Codex access token missing. Run `codex` to log in.")

    if needs_refresh(auth):
        refreshed = refresh_token(auth)
        if refreshed:
            access = refreshed

    data, headers = fetch_usage(access, tokens.get("account_id"))

    header_primary = read_number(headers.get("x-codex-primary-used-percent"))
    header_secondary = read_number(headers.get("x-codex-secondary-used-percent"))

    rate_limit = data.get("rate_limit") if isinstance(data.get("rate_limit"), dict) else {}
    primary_window = rate_limit.get("primary_window") if isinstance(rate_limit.get("primary_window"), dict) else {}
    secondary_window = rate_limit.get("secondary_window") if isinstance(rate_limit.get("secondary_window"), dict) else {}

    session = header_primary if header_primary is not None else read_number(primary_window.get("used_percent"))
    weekly = header_secondary if header_secondary is not None else read_number(secondary_window.get("used_percent"))

    if session is None or weekly is None:
        fail("Missing usage percent values.")

    payload = {
        "sessionPercent": float(session),
        "weeklyPercent": float(weekly),
        "sessionResetAt": reset_from_window(primary_window),
        "weeklyResetAt": reset_from_window(secondary_window),
        "updatedAt": datetime.now(timezone.utc).isoformat(),
    }

    print(json.dumps(payload))


if __name__ == "__main__":
    main()
