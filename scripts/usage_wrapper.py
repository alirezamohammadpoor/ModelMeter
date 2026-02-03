#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone
from typing import Any, Optional


def read_input(cmd: Optional[str], file_path: Optional[str]) -> str:
    if cmd:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode != 0:
            stderr = result.stderr.strip()
            raise RuntimeError(stderr or f"Command failed with exit code {result.returncode}.")
        return result.stdout
    if file_path:
        with open(file_path, "r", encoding="utf-8") as handle:
            return handle.read()
    return sys.stdin.read()


def get_path(obj: Any, path: str) -> Optional[Any]:
    cur = obj
    for key in path.split("."):
        if not isinstance(cur, dict) or key not in cur:
            return None
        cur = cur[key]
    return cur


def read_number(value: Any) -> Optional[float]:
    try:
        num = float(value)
        if num != num:  # NaN
            return None
        return num
    except (TypeError, ValueError):
        return None


def first_number(obj: Any, paths: list[str]) -> Optional[float]:
    for path in paths:
        value = get_path(obj, path)
        num = read_number(value)
        if num is not None:
            return num
    return None


def read_reset(obj: Any, paths: list[str]) -> Optional[str]:
    for path in paths:
        value = get_path(obj, path)
        if isinstance(value, str) and value.strip():
            return value
        if isinstance(value, (int, float)):
            return datetime.fromtimestamp(float(value), tz=timezone.utc).isoformat()
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description="Wrap a provider command into MenuUsage JSON.")
    parser.add_argument("--cmd", help="Shell command to run and parse JSON output")
    parser.add_argument("--file", help="Read JSON from file instead of running a command")
    args = parser.parse_args()

    raw = read_input(args.cmd, args.file).strip()
    if not raw:
        print("Empty input.", file=sys.stderr)
        return 1

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        print(f"Invalid JSON: {exc}", file=sys.stderr)
        return 1

    session = first_number(
        data,
        [
            "sessionPercent",
            "session_percent",
            "five_hour.utilization",
            "fiveHour.utilization",
            "rate_limit.primary_window.used_percent",
            "rateLimit.primaryWindow.used_percent",
            "primary_window.used_percent",
        ],
    )
    weekly = first_number(
        data,
        [
            "weeklyPercent",
            "weekly_percent",
            "seven_day.utilization",
            "sevenDay.utilization",
            "rate_limit.secondary_window.used_percent",
            "rateLimit.secondaryWindow.used_percent",
            "secondary_window.used_percent",
        ],
    )

    if session is None or weekly is None:
        print("Missing session or weekly percent values.", file=sys.stderr)
        return 1

    session_reset = read_reset(
        data,
        [
            "five_hour.resets_at",
            "fiveHour.resets_at",
            "primary_window.reset_at",
            "rate_limit.primary_window.reset_at",
            "rateLimit.primaryWindow.reset_at",
        ],
    )
    weekly_reset = read_reset(
        data,
        [
            "seven_day.resets_at",
            "sevenDay.resets_at",
            "secondary_window.reset_at",
            "rate_limit.secondary_window.reset_at",
            "rateLimit.secondaryWindow.reset_at",
        ],
    )

    payload = {
        "sessionPercent": session,
        "weeklyPercent": weekly,
        "sessionResetAt": session_reset,
        "weeklyResetAt": weekly_reset,
        "updatedAt": datetime.now(timezone.utc).isoformat(),
    }
    print(json.dumps(payload))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
