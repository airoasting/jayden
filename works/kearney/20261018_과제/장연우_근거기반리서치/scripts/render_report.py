#!/usr/bin/env python3
"""Render an ax-research report.json into one self-contained report.html.

Usage:  python3 render_report.py report.json [report.html]

The renderer recomputes every round average from the reviewer scores as integer
tenths and refuses to label a report 통과 unless the latest round actually passes
(all reviewers on the latest version, average >= target before rounding, no open
blocking/major findings). See references/07-html-report.md for the schema.
Exit codes: 0 ok, 2 invalid input.
"""
import json
import sys
from decimal import Decimal, InvalidOperation
from html import escape as e

STATUSES = ("통과", "추가 입력 필요", "기준 미달")
TYPES = ("사실", "해석", "가정", "합성 예시")


def tenths(v, label):
    try:
        d = Decimal(str(v)) * 10
    except InvalidOperation:
        raise ValueError(f"{label}: not a number: {v!r}")
    if d != d.to_integral_value():
        raise ValueError(f"{label}: more than one decimal place")
    return int(d)


def round_result(rnd, target_t, reviewers):
    names = list(rnd["scores"])
    if set(names) != set(reviewers):
        raise ValueError(f"round {rnd['round']}: reviewers must be exactly {reviewers}")
    ts = [tenths(rnd["scores"][n], f"round {rnd['round']} {n}") for n in names]
    if any(t < 0 or t > 100 for t in ts):
        raise ValueError(f"round {rnd['round']}: score outside 0-10")
    total = sum(ts)
    open_n = int(rnd.get("open_blocking_or_major", 0))
    passed = total >= target_t * len(ts) and open_n == 0
    return {"total": total, "n": len(ts), "avg": total / 10 / len(ts), "passed": passed, "open": open_n}


def validate(d):
    for k in ("title", "status", "version", "question", "conclusion", "sources", "evidence", "review"):
        if k not in d:
            raise ValueError(f"missing field: {k}")
    if d["status"] not in STATUSES:
        raise ValueError(f"status must be one of {STATUSES}")
    ids = {s["id"] for s in d["sources"]}
    for ev in d["evidence"]:
        if ev["source"] not in ids:
            raise ValueError(f"{ev['id']}: unknown source {ev['source']}")
        if ev["type"] not in TYPES:
            raise ValueError(f"{ev['id']}: type must be one of {TYPES}")
    eids = {ev["id"] for ev in d["evidence"]}
    for imp in d.get("implications", []):
        for x in imp["evidence"]:
            if x not in eids:
                raise ValueError(f"implication cites unknown evidence {x}")
    rev = d["review"]
    target_t = tenths(rev.get("target", 9.5), "target")
    rounds = rev["rounds"]
    if not rounds or len(rounds) > rev.get("max_rounds", 5):
        raise ValueError("rounds must be 1..max_rounds")
    results = [round_result(r, target_t, rev["reviewers"]) for r in rounds]
    latest_ok = results[-1]["passed"] and rounds[-1]["version"] == d["version"]
    if d["status"] == "통과" and not latest_ok:
        raise ValueError("status 통과 but the latest round on the final version does not pass")
    if d["status"] != "통과" and latest_ok:
        raise ValueError("latest round passes; status must be 통과")
    return results, target_t


def p(s):
    return f"<p>{e(s)}</p>"


def render(d):
    results, target_t = validate(d)
    rev = d["review"]
    badge = {"통과": "ok", "추가 입력 필요": "warn", "기준 미달": "bad"}[d["status"]]
    out = []
    a = out.append
    a(f"""<!doctype html>
<html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{e(d['title'])}</title>
<style>{CSS}</style></head><body><main>
<header><span class="eyebrow">ax-research 보고서 · {e(d.get('date',''))} · {e(d['version'])}</span>
<h1>{e(d['title'])}</h1>
<p class="status {badge}">{e(d['status'])}</p>
{'<p class="note">미통과 결과이므로 아래 내용은 잠정 결과입니다.</p>' if d['status']!='통과' else ''}
<p class="q"><b>조사 질문.</b> {e(d['question'])}</p></header>
<section><h2>1. 핵심 결론</h2>{''.join(p(x) for x in d['conclusion'])}</section>""")
    a('<section><h2>2. 근거와 비교</h2><h3>출처</h3><div class="scroll"><table><thead><tr><th>ID</th><th>제목·작성 주체</th><th>확인한 위치</th><th>기준일</th><th>확인 상태</th></tr></thead><tbody>')
    for s in d["sources"]:
        a(f"<tr><td class=id>{e(s['id'])}</td><td>{e(s['title'])}</td><td class=break>{e(s['locator'])}</td><td>{e(s.get('date','미확인'))}</td><td>{e(s['status'])}</td></tr>")
    a('</tbody></table></div><h3>근거</h3><div class="scroll"><table><thead><tr><th>ID</th><th>출처</th><th>주장</th><th>구분</th><th>원문 위치</th><th>범위</th><th>한계</th></tr></thead><tbody>')
    for ev in d["evidence"]:
        a(f"<tr><td class=id>{e(ev['id'])}</td><td class=id>{e(ev['source'])}</td><td>{e(ev['claim'])}</td><td><span class='tag t{TYPES.index(ev['type'])}'>{e(ev['type'])}</span></td><td>{e(ev['location'])}</td><td>{e(ev['scope'])}</td><td>{e(ev['limit'])}</td></tr>")
    a("</tbody></table></div>")
    if d.get("benchmark"):
        b = d["benchmark"]
        a(f"<h3>벤치마크</h3><p class=small>비교 축 선택 이유: {e(b['why'])}</p><div class=scroll><table><thead><tr><th>대상</th><th>값</th><th>단위·기간·분모</th><th>근거</th><th>비교 가능 여부</th></tr></thead><tbody>")
        for r in b["rows"]:
            a(f"<tr><td>{e(r['name'])}</td><td>{e(r['value'])}</td><td>{e(r['basis'])}</td><td class=id>{e(', '.join(r['evidence']))}</td><td>{e(r['comparable'])}</td></tr>")
        a("</tbody></table></div>")
    a("</section><section><h2>3. 시사점과 남은 질문</h2>")
    for imp in d.get("implications", []):
        a(f"<article class=card><p><b>{e(imp['text'])}</b></p><dl><dt>근거</dt><dd class=id>{e(', '.join(imp['evidence']))}</dd><dt>적용 조건</dt><dd>{e(imp['conditions'])}</dd><dt>대안 해석</dt><dd>{e(imp['alternatives'])}</dd><dt>추가 확인</dt><dd>{e(imp['questions'])}</dd></dl></article>")
    if d.get("unverified"):
        a("<h3>미확인 항목</h3><ul>" + "".join(f"<li>{e(x)}</li>" for x in d["unverified"]) + "</ul>")
    a("</section>")
    last = results[-1]
    a(f"<section><h2>4. 검토 요약</h2><p><b>실제 검토 방식.</b> {e(rev['method'])}</p>")
    a(f"<p><b>최종 버전 {e(d['version'])} 판정.</b> 합계 {last['total']/10:.1f} ÷ {last['n']} = <b>{last['avg']:.3f}</b> (목표 {target_t/10:.1f}), 미해결 차단·중대 지적 {last['open']}건.</p>")
    a("<div class=scroll><table><thead><tr><th>라운드</th><th>버전</th>" + "".join(f"<th>{e(n)}</th>" for n in rev["reviewers"]) + "<th>평균</th><th>미해결 차단·중대</th><th>통과</th></tr></thead><tbody>")
    for r, res in zip(rev["rounds"], results):
        a(f"<tr><td>{r['round']}</td><td>{e(r['version'])}</td>" + "".join(f"<td>{Decimal(str(r['scores'][n])):.1f}</td>" for n in rev["reviewers"]) + f"<td>{res['avg']:.3f}</td><td>{res['open']}</td><td>{'예' if res['passed'] else '아니오'}</td></tr>")
    a("</tbody></table></div>")
    for title, key in (("주요 수정", "changes"), ("남은 지적", "remaining")):
        if rev.get(key):
            a(f"<h3>{title}</h3><ul>" + "".join(f"<li>{e(x)}</li>" for x in rev[key]) + "</ul>")
    a(f"<p><b>종료 이유.</b> {e(rev['end_reason'])}</p></section></main></body></html>")
    return "".join(out)


CSS = """
:root{--bg:#F3F4F1;--surface:#fff;--ink:#1B232B;--muted:#59656F;--line:#D3D9DD;--accent:#2E5E66;
--ok:#2F6B45;--ok-bg:#DDEEE3;--warn:#8A5A12;--warn-bg:#F6E9CC;--bad:#9A3A22;--bad-bg:#F5DDD5;--chip:#E4EAEC}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#12181D;--surface:#1A232A;--ink:#E7ECEF;--muted:#9AA8B2;--line:#2C3943;--accent:#86BDC5;
--ok:#8CCB9F;--ok-bg:#1B3325;--warn:#E3BE7A;--warn-bg:#392D12;--bad:#E3A18C;--bad-bg:#3A2218;--chip:#25323A;color-scheme:dark}}
:root[data-theme="dark"]{--bg:#12181D;--surface:#1A232A;--ink:#E7ECEF;--muted:#9AA8B2;--line:#2C3943;--accent:#86BDC5;
--ok:#8CCB9F;--ok-bg:#1B3325;--warn:#E3BE7A;--warn-bg:#392D12;--bad:#E3A18C;--bad-bg:#3A2218;--chip:#25323A;color-scheme:dark}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.65 "IBM Plex Sans","Noto Sans KR","Apple SD Gothic Neo",system-ui,sans-serif;
padding:32px max(16px,env(safe-area-inset-right)) 64px max(16px,env(safe-area-inset-left))}
main{max-width:900px;margin:0 auto;display:flex;flex-direction:column;gap:36px}
h1,h2{font-family:"Newsreader","Noto Serif KR",Georgia,serif;margin:0;line-height:1.2;text-wrap:balance}
h1{font-size:clamp(1.8rem,5vw,2.5rem)}h2{font-size:1.5rem;margin-bottom:12px}h3{font-size:1rem;margin:18px 0 8px}
p{margin:0 0 10px}.small,.note{color:var(--muted);font-size:.9rem}
.eyebrow{font:500 .75rem ui-monospace,monospace;letter-spacing:.1em;text-transform:uppercase;color:var(--accent)}
header{display:flex;flex-direction:column;gap:10px}
.status{display:inline-block;align-self:flex-start;font-weight:600;padding:2px 12px;border-radius:4px;margin:0}
.ok{background:var(--ok-bg);color:var(--ok)}.warn{background:var(--warn-bg);color:var(--warn)}.bad{background:var(--bad-bg);color:var(--bad)}
.scroll{overflow-x:auto;border:1px solid var(--line);border-radius:6px;background:var(--surface)}
table{border-collapse:collapse;width:100%;font-size:.875rem}
th,td{text-align:left;vertical-align:top;padding:8px 10px;border-bottom:1px solid var(--line);min-width:72px}
th{font:500 .72rem ui-monospace,monospace;letter-spacing:.05em;text-transform:uppercase;color:var(--muted)}
tr:last-child td{border-bottom:0}.id{font-family:ui-monospace,monospace;white-space:nowrap}.break{overflow-wrap:anywhere;min-width:160px}
.tag{font-size:.75rem;padding:1px 8px;border-radius:3px;background:var(--chip);white-space:nowrap}
.card{background:var(--surface);border:1px solid var(--line);border-radius:6px;padding:14px 16px;margin-bottom:12px}
dl{display:grid;grid-template-columns:90px 1fr;gap:4px 12px;margin:8px 0 0;font-size:.9rem}dt{color:var(--muted)}dd{margin:0;min-width:0}
@media (max-width:560px){dl{grid-template-columns:1fr}}
"""

if __name__ == "__main__":
    if len(sys.argv) not in (2, 3):
        print(__doc__)
        sys.exit(2)
    try:
        with open(sys.argv[1], encoding="utf-8") as f:
            html = render(json.load(f))
    except (ValueError, KeyError, OSError, json.JSONDecodeError) as ex:
        print(f"입력 오류: {ex!r}", file=sys.stderr)
        sys.exit(2)
    dest = sys.argv[2] if len(sys.argv) == 3 else sys.argv[1].rsplit(".", 1)[0] + ".html"
    with open(dest, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"wrote {dest}")
