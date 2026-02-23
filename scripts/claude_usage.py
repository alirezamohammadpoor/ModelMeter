#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from typing import Optional, Dict, Any, Tuple

CRED_PATHS = [
    os.path.expanduser("~/.claude/.credentials.json"),
    os.path.expanduser("~/.config/claude/.credentials.json"),
]
USAGE_URLS = [
    os.environ.get("CLAUDE_USAGE_URL", "").strip(),
    "https://claude.ai/api/oauth/usage",
    "https://api.anthropic.com/api/oauth/usage",
]
TOKEN_URLS = [
    os.environ.get("CLAUDE_TOKEN_URL", "").strip(),
    "https://claude.ai/api/oauth/token",
]
CLIENT_ID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
SCOPES = "user:profile user:inference user:sessions:claude_code user:mcp_servers"
REFRESH_BUFFER_MS = 5 * 60 * 1000


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def keychain_read() -> Optional[dict]:
    try:
        result = subprocess.run(
            ["security", "find-generic-password", "-s", "Claude Code-credentials", "-w"],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            return None
        raw = result.stdout.strip()
        if not raw:
            return None
        return json.loads(raw)
    except Exception:
        return None


def keychain_write(payload: dict) -> None:
    try:
        subprocess.run(
            ["security", "add-generic-password", "-s", "Claude Code-credentials", "-U", "-w", json.dumps(payload)],
            check=False,
            capture_output=True,
            text=True,
        )
    except Exception:
        pass


def read_credentials() -> Tuple[dict, str, Optional[str]]:
    for path in CRED_PATHS:
        if not os.path.exists(path):
            continue
        try:
            with open(path, "r", encoding="utf-8") as handle:
                return json.load(handle), "file", path
        except Exception:
            fail("Failed to read Claude credentials.")

    keychain_payload = keychain_read()
    if keychain_payload is not None:
        return keychain_payload, "keychain", None

    fail("Credentials not found. Run `claude` to log in.")
    return {}, "missing", None


def write_credentials(payload: dict, source: str, path: Optional[str]) -> None:
    if source == "keychain":
        keychain_write(payload)
        return
    if not path:
        return
    try:
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2)
    except Exception:
        pass


def request_json(
    url: str,
    method: str,
    headers: dict,
    body: Optional[dict],
    timeout: int = 15
) -> Tuple[int, Dict[str, Any], Dict[str, Any], Optional[str]]:
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, method=method)
    for key, value in headers.items():
        req.add_header(key, value)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            status = resp.getcode()
            raw = resp.read().decode("utf-8")
            payload = json.loads(raw) if raw else {}
            return status, payload, dict(resp.headers), None
    except urllib.error.HTTPError as exc:
        return exc.code, {}, {}, str(exc)
    except Exception as exc:
        return 0, {}, {}, str(exc)
    return 0, {}, {}, "Unknown error"


def needs_refresh(oauth: dict) -> bool:
    expires_at = oauth.get("expiresAt")
    if not isinstance(expires_at, (int, float)):
        return True
    return (int(time.time() * 1000) + REFRESH_BUFFER_MS) >= int(expires_at)


def refresh_token(oauth: dict, creds: dict, source: str, path: Optional[str]) -> Optional[str]:
    refresh = oauth.get("refreshToken")
    if not isinstance(refresh, str) or not refresh.strip():
        return None

    payload = None
    access = None
    for url in [u for u in TOKEN_URLS if u]:
        status, body, _, _ = request_json(
            url,
            "POST",
            {"Content-Type": "application/json"},
            {
                "grant_type": "refresh_token",
                "refresh_token": refresh,
                "client_id": CLIENT_ID,
                "scope": SCOPES,
            },
            timeout=15,
        )
        if status < 200 or status >= 300:
            continue
        access = body.get("access_token")
        if isinstance(access, str) and access.strip():
            payload = body
            break

    if payload is None or access is None:
        return None

    oauth["accessToken"] = access
    if isinstance(payload.get("refresh_token"), str):
        oauth["refreshToken"] = payload.get("refresh_token")
    if isinstance(payload.get("expires_in"), (int, float)):
        oauth["expiresAt"] = int(time.time() * 1000) + int(payload.get("expires_in")) * 1000

    creds["claudeAiOauth"] = oauth
    write_credentials(creds, source, path)
    return access


def fetch_usage(token: str) -> dict:
    last_error = None
    for url in [u for u in USAGE_URLS if u]:
        status, payload, _, err = request_json(
            url,
            "GET",
            {
                "Authorization": f"Bearer {token}",
                "Accept": "application/json",
                "Content-Type": "application/json",
                "anthropic-beta": "oauth-2025-04-20",
                "User-Agent": "ModelMeter",
            },
            None,
            timeout=10,
        )
        if status < 200 or status >= 300:
            if status == 0 and err:
                last_error = f"Request failed: {err}"
            else:
                last_error = f"HTTP {status} from {url}"
            continue
        five_hour = payload.get("five_hour", {}) if isinstance(payload.get("five_hour"), dict) else {}
        seven_day = payload.get("seven_day", {}) if isinstance(payload.get("seven_day"), dict) else {}
        if isinstance(five_hour.get("utilization"), (int, float)) and isinstance(seven_day.get("utilization"), (int, float)):
            return payload
        last_error = f"Missing usage fields from {url}"
    fail(f"Usage request failed: {last_error or 'No response.'}")


def to_iso(ts):
    if isinstance(ts, (int, float)):
        return datetime.fromtimestamp(float(ts), tz=timezone.utc).isoformat()
    return None


def normalize_percent(value) -> float:
    try:
        numeric = float(value)
    except Exception:
        return 0.0
    # Claude API returns utilization already in 0..100 scale.
    return numeric


def main() -> None:
    creds, source, path = read_credentials()
    oauth = creds.get("claudeAiOauth")
    if not isinstance(oauth, dict):
        fail("Claude OAuth credentials missing. Run `claude` to log in.")

    access = oauth.get("accessToken")
    if not isinstance(access, str) or not access.strip():
        fail("Claude access token missing. Run `claude` to log in.")

    if needs_refresh(oauth):
        refreshed = refresh_token(oauth, creds, source, path)
        if refreshed:
            access = refreshed
        else:
            fail("Token expired. Run `claude` to re-authenticate.")

    data = fetch_usage(access)
    five_hour = data.get("five_hour", {}) if isinstance(data.get("five_hour"), dict) else {}
    seven_day = data.get("seven_day", {}) if isinstance(data.get("seven_day"), dict) else {}

    session_percent = normalize_percent(five_hour.get("utilization", 0.0))
    weekly_percent = normalize_percent(seven_day.get("utilization", 0.0))

    payload = {
        "sessionPercent": session_percent,
        "weeklyPercent": weekly_percent,
        "sessionResetAt": to_iso(five_hour.get("resets_at")),
        "weeklyResetAt": to_iso(seven_day.get("resets_at")),
        "updatedAt": datetime.now(timezone.utc).isoformat(),
    }

    print(json.dumps(payload))


if __name__ == "__main__":
    main()
