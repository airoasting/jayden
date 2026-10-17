#!/usr/bin/env python3
"""Decide whether a review round passes the ax-research gate.

Usage:  python3 check_pass.py round.json

round.json:
{
  "version": "v2",
  "target": 9.5,                      # optional, default 9.5
  "unresolved_blocking_or_major": 0,  # count of open 차단/중대 findings
  "reviewers": [
    {"name": "Red 1", "version": "v2", "items": [1.9, 1.9, 2.0, 1.8, 1.9]},
    {"name": "Red 2", "version": "v2", "items": [2.0, 1.9, 1.9, 1.9, 1.9]},
    {"name": "Red 3", "version": "v2", "items": [1.9, 1.9, 1.9, 2.0, 1.9]}
  ]
}

items are the five rubric scores (0-2, one decimal): 정확성과 구분, 출처 추적성,
분석·비교 타당성, 의사결정 유용성, 완결성과 한계.

Scores are compared as integer tenths so no rounding can flip the verdict.
Exit codes: 0 pass, 1 fail, 2 invalid input.
"""
import json
import sys
from decimal import Decimal, InvalidOperation


def tenths(value, label):
    try:
        d = Decimal(str(value))
    except InvalidOperation:
        raise ValueError(f"{label}: not a number: {value!r}")
    t = d * 10
    if t != t.to_integral_value():
        raise ValueError(f"{label}: more than one decimal place: {value}")
    return int(t)


def main(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    version = data.get("version")
    reviewers = data.get("reviewers", [])
    if not version or not reviewers:
        raise ValueError("version and at least one reviewer are required")

    target_t = tenths(data.get("target", 9.5), "target")  # tenths of a point
    open_findings = int(data.get("unresolved_blocking_or_major", 0))

    totals = []
    for r in reviewers:
        name = r.get("name", "?")
        if r.get("version") != version:
            raise ValueError(f"{name}: reviewed {r.get('version')!r}, latest is {version!r}")
        items = r.get("items", [])
        if len(items) != 5:
            raise ValueError(f"{name}: expected 5 item scores, got {len(items)}")
        item_t = [tenths(v, f"{name} item {i + 1}") for i, v in enumerate(items)]
        if any(t < 0 or t > 20 for t in item_t):
            raise ValueError(f"{name}: each item must be between 0 and 2")
        totals.append((name, sum(item_t)))  # tenths of a point, 0-100

    n = len(totals)
    sum_t = sum(t for _, t in totals)
    passed_score = sum_t >= target_t * n  # avg >= target without division

    for name, t in totals:
        print(f"{name}: {t / 10:.1f}")
    print(f"합계 {sum_t / 10:.1f} ÷ {n} = {sum_t / 10 / n:.3f} (목표 {target_t / 10:.1f})")
    print(f"미해결 차단·중대 지적: {open_findings}")

    ok = passed_score and open_findings == 0
    print("판정: 통과" if ok else "판정: 미통과")
    return 0 if ok else 1


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    try:
        sys.exit(main(sys.argv[1]))
    except (ValueError, OSError, json.JSONDecodeError) as e:
        print(f"입력 오류: {e}", file=sys.stderr)
        sys.exit(2)
