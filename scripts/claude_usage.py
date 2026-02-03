#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import time
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
CONFIG_PATH = os.path.expanduser("~/.menuusage/config.json")


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

    fail("Claude credentials not found. Run `claude` to log in.")
    return {}, "missing", None


def read_config() -> dict:
    if not os.path.exists(CONFIG_PATH):
        return {}
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except Exception:
        return {}


def cookie_header_from_config() -> Optional[str]:
    cfg = read_config()
    if not isinstance(cfg, dict):
        return None
    raw = cfg.get("claudeCookieHeader")
    if isinstance(raw, str) and raw.strip():
        return raw.strip()
    return None


def normalize_cookie_header(value: str) -> str:
    trimmed = value.strip()
    lower = trimmed.lower()
    if lower.startswith("cookie:"):
        return trimmed.split(":", 1)[1].strip()
    return trimmed


def session_key_from_cookie(cookie_header: str) -> Optional[str]:
    raw = normalize_cookie_header(cookie_header)
    parts = [part.strip() for part in raw.split(";") if part.strip()]
    for part in parts:
        if part.startswith("sessionKey="):
            return part.split("=", 1)[1]
    return None


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
        status, body, _, err = request_json(
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
                "User-Agent": "MenuUsage",
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
    fail(f"Usage request failed. {last_error or 'No response.'}")


def request_web_json(url: str, cookie_header: str) -> dict:
    headers = {
        "Cookie": normalize_cookie_header(cookie_header),
        "Accept": "application/json",
        "User-Agent": "MenuUsage",
    }
    status, payload, _, err = request_json(url, "GET", headers, None, timeout=10)
    if status < 200 or status >= 300:
        if status == 0 and err:
            fail(f"Claude web request failed: {err}")
        fail(f"Claude web request failed (HTTP {status}).")
    return payload


def fetch_web_usage(cookie_header: str) -> dict:
    session_key = session_key_from_cookie(cookie_header)
    if not session_key:
        fail("Claude cookie header missing sessionKey.")
    organizations = request_web_json("https://claude.ai/api/organizations", cookie_header)
    org_id = None
    if isinstance(organizations, list):
        for entry in organizations:
            if isinstance(entry, dict) and isinstance(entry.get("uuid"), str):
                org_id = entry.get("uuid")
                break
    if not org_id:
        fail("No Claude organization found.")
    return request_web_json(f"https://claude.ai/api/organizations/{org_id}/usage", cookie_header)


def main() -> None:
    cookie_header = os.environ.get("CLAUDE_COOKIE_HEADER") or os.environ.get("CLAUDE_COOKIE")
    if not cookie_header:
        cookie_header = cookie_header_from_config()

    data = None
    try:
        creds, source, path = read_credentials()
        oauth = creds.get("claudeAiOauth")
        if not isinstance(oauth, dict):
            raise RuntimeError("Claude OAuth missing.")

        access = oauth.get("accessToken")
        if not isinstance(access, str) or not access.strip():
            raise RuntimeError("Claude access token missing.")

        if needs_refresh(oauth):
            refreshed = refresh_token(oauth, creds, source, path)
            if refreshed:
                access = refreshed

        data = fetch_usage(access)
    except SystemExit as exc:
        if cookie_header:
            data = fetch_web_usage(cookie_header)
        else:
            raise exc

    five_hour = data.get("five_hour", {}) if isinstance(data.get("five_hour"), dict) else {}
    seven_day = data.get("seven_day", {}) if isinstance(data.get("seven_day"), dict) else {}

    session = five_hour.get("utilization")
    weekly = seven_day.get("utilization")

    if not isinstance(session, (int, float)) or not isinstance(weekly, (int, float)):
        fail("Missing usage percent values.")

    payload = {
        "sessionPercent": float(session),
        "weeklyPercent": float(weekly),
        "sessionResetAt": five_hour.get("resets_at"),
        "weeklyResetAt": seven_day.get("resets_at"),
        "updatedAt": datetime.now(timezone.utc).isoformat(),
    }

    print(json.dumps(payload))


if __name__ == "__main__":
    main()
