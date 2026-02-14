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
USAGE_URL = os.environ.get("CLAUDE_USAGE_URL", "").strip() or "https://api.anthropic.com/api/oauth/usage"
TOKEN_URL = os.environ.get("CLAUDE_TOKEN_URL", "").strip() or "https://platform.claude.com/v1/oauth/token"
CLIENT_ID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
SCOPES = "user:profile user:inference user:sessions:claude_code user:mcp_servers"
REFRESH_BUFFER_MS = 5 * 60 * 1000


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def try_decode_hex(raw: str) -> str:
    """Decode hex-encoded keychain output (macOS edge case)."""
    cleaned = raw.strip()
    if not cleaned:
        return cleaned
    if all(c in "0123456789abcdefABCDEF" for c in cleaned) and len(cleaned) % 2 == 0:
        try:
            return bytes.fromhex(cleaned).decode("utf-8")
        except Exception:
            pass
    return cleaned


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
        raw = try_decode_hex(raw)
        if not raw:
            return None
        return json.loads(raw)
    except Exception:
        return None


def keychain_write(payload: dict) -> None:
    try:
        subprocess.run(
            ["security", "add-generic-password", "-s", "Claude Code-credentials", "-U", "-w",
             json.dumps(payload, separators=(",", ":"))],
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
            json.dump(payload, handle, separators=(",", ":"))
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

    status, body, _, _ = request_json(
        TOKEN_URL,
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
        return None
    access = body.get("access_token")
    if not isinstance(access, str) or not access.strip():
        return None

    oauth["accessToken"] = access
    if isinstance(body.get("refresh_token"), str):
        oauth["refreshToken"] = body.get("refresh_token")
    if isinstance(body.get("expires_in"), (int, float)):
        oauth["expiresAt"] = int(time.time() * 1000) + int(body.get("expires_in")) * 1000

    creds["claudeAiOauth"] = oauth
    write_credentials(creds, source, path)
    return access


def fetch_usage(token: str) -> Tuple[int, dict]:
    status, payload, _, err = request_json(
        USAGE_URL,
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
    return status, payload


def fetch_usage_with_retry(
    token: str, oauth: dict, creds: dict, source: str, path: Optional[str]
) -> Tuple[dict, str]:
    status, payload = fetch_usage(token)
    if status in (401, 403):
        print(f"Got HTTP {status}, attempting token refresh...", file=sys.stderr)
        refreshed = refresh_token(oauth, creds, source, path)
        if refreshed:
            status, payload = fetch_usage(refreshed)
            if 200 <= status < 300:
                return payload, refreshed
    if 200 <= status < 300:
        return payload, token
    fail(f"Usage request failed: HTTP {status} from {USAGE_URL}")


def to_iso(ts):
    if isinstance(ts, str) and ts.strip():
        return ts.strip()
    if isinstance(ts, (int, float)):
        return datetime.fromtimestamp(float(ts), tz=timezone.utc).isoformat()
    return None


def normalize_percent(value) -> float:
    try:
        numeric = float(value)
    except Exception:
        return 0.0
    # Some APIs return utilization in 0..1, others already in 0..100.
    return numeric * 100.0 if numeric <= 1.0 else numeric


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

    data, access = fetch_usage_with_retry(access, oauth, creds, source, path)
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
