#!/usr/bin/env python3
"""Tests for render_report.py. Run: python3 scripts/test_render.py"""
import copy
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(__file__))
from render_report import render  # noqa: E402

BASE = {
    "title": "테스트 보고서", "date": "2026-10-17", "status": "통과", "version": "v2",
    "question": "질문?", "conclusion": ["결론 문단"],
    "sources": [{"id": "S-001", "title": "자료", "locator": "https://example.com/a", "date": "2026-01-01", "status": "전문 확인"}],
    "evidence": [{"id": "E-001", "source": "S-001", "claim": "주장", "type": "사실", "location": "2문단", "scope": "범위", "limit": "한계"}],
    "implications": [{"text": "시사점", "evidence": ["E-001"], "conditions": "조건", "alternatives": "대안", "questions": "질문"}],
    "review": {
        "method": "별도 Subagent 3명", "target": 9.5, "max_rounds": 5,
        "reviewers": ["Red 1", "Red 2", "Red 3"],
        "rounds": [
            {"round": 1, "version": "v1", "scores": {"Red 1": 8.0, "Red 2": 8.5, "Red 3": 8.0}, "open_blocking_or_major": 2},
            {"round": 2, "version": "v2", "scores": {"Red 1": 9.5, "Red 2": 9.6, "Red 3": 9.5}, "open_blocking_or_major": 0},
        ],
        "end_reason": "기준 충족",
    },
}


def variant(fn):
    d = copy.deepcopy(BASE)
    fn(d)
    return d


class RenderTests(unittest.TestCase):
    def test_passing_report_renders(self):
        html = render(BASE)
        self.assertIn('lang="ko"', html)
        self.assertIn("통과", html)
        self.assertIn("9.533", html)  # 28.6 / 3
        self.assertIn("E-001", html)

    def test_pass_status_rejected_when_latest_round_fails(self):
        d = variant(lambda x: x["review"]["rounds"][1]["scores"].update({"Red 3": 9.0}))
        with self.assertRaises(ValueError):
            render(d)

    def test_average_below_target_by_rounding_is_not_pass(self):
        # 9.5 + 9.5 + 9.4 = 28.4 / 3 = 9.4667 -> would round to 9.5, must fail
        def f(x):
            x["review"]["rounds"][1]["scores"] = {"Red 1": 9.5, "Red 2": 9.5, "Red 3": 9.4}
        with self.assertRaises(ValueError):
            render(variant(f))
        d = variant(f)
        d["status"] = "기준 미달"
        self.assertIn("기준 미달", render(d))

    def test_open_blocking_finding_blocks_pass(self):
        d = variant(lambda x: x["review"]["rounds"][1].update({"open_blocking_or_major": 1}))
        with self.assertRaises(ValueError):
            render(d)

    def test_failed_status_must_match_when_latest_passes(self):
        with self.assertRaises(ValueError):
            render(variant(lambda x: x.update({"status": "기준 미달"})))

    def test_latest_round_must_be_final_version(self):
        with self.assertRaises(ValueError):
            render(variant(lambda x: x.update({"version": "v3"})))

    def test_unknown_source_and_evidence_rejected(self):
        with self.assertRaises(ValueError):
            render(variant(lambda x: x["evidence"][0].update({"source": "S-009"})))
        with self.assertRaises(ValueError):
            render(variant(lambda x: x["implications"][0].update({"evidence": ["E-009"]})))

    def test_reviewer_set_must_match(self):
        with self.assertRaises(ValueError):
            render(variant(lambda x: x["review"]["rounds"][1]["scores"].pop("Red 3")))

    def test_html_is_escaped(self):
        d = variant(lambda x: x["conclusion"].append("<script>alert(1)</script>"))
        html = render(d)
        self.assertNotIn("<script>alert(1)</script>", html)
        self.assertIn("&lt;script&gt;", html)

    def test_non_pass_report_is_marked_provisional(self):
        d = variant(lambda x: x["review"]["rounds"].pop())
        d["version"] = "v1"
        d["status"] = "기준 미달"
        self.assertIn("잠정 결과", render(d))


class RealRunTests(unittest.TestCase):
    """Every saved results/*/report.json must render and agree with its rounds/*.json files."""

    def test_saved_reports_render_and_match_round_files(self):
        import glob
        import json
        root = os.path.join(os.path.dirname(__file__), "..", "results")
        for path in glob.glob(os.path.join(root, "*", "report.json")):
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
            html = render(data)
            self.assertIn(data["status"], html)
            self.assertIn("lang=\"ko\"", html)
            last = data["review"]["rounds"][-1]
            round_file = os.path.join(os.path.dirname(path), "rounds", f"round-{last['round']}.json")
            if os.path.exists(round_file):
                with open(round_file, encoding="utf-8") as f:
                    rf = json.load(f)
                sheet = sum(round(sum(r["items"]) * 10) for r in rf["reviewers"])
                report = round(sum(last["scores"].values()) * 10)
                self.assertEqual(sheet, report, path)


if __name__ == "__main__":
    unittest.main(verbosity=2)
