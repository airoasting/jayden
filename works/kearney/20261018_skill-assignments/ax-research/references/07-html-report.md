# HTML 보고서 산출

사용자가 HTML 보고서를 원하면(또는 형식이 정해지지 않았고 파일 저장 범위에 포함될 때 제안) 최종 결과를 `report.json`으로 만들고 `scripts/render_report.py`로 단일 파일 `report.html`을 생성한다. 이 경우 출처 등록부와 근거 장부는 별도 Markdown 대신 `report.json`의 `sources`와 `evidence`가 단일 원본이다.

```
python3 scripts/render_report.py results/<실행폴더>/report.json results/<실행폴더>/report.html
python3 scripts/test_render.py        # 렌더러 자체 테스트
```

`report.html`은 독립 실행 문서다(`<!doctype>`, 라이트·다크 테마, 모바일 폭 대응). 웹 페이지 게시 도구가 문서 골격을 직접 붙이는 환경에서는 `<title>`, `<style>`, `<main>`만 남긴 조각 파일(`report-artifact.html`)을 만들어 게시한다.

## 작업 순서

1. 초안은 `drafts/report-vN.json`으로 저장하고 `review.rounds`는 비워 둔다. 이 파일을 Red에게 전달한다.
2. 라운드마다 Red 점수를 받아 `rounds/round-N.json`(check_pass.py 형식)에 기록하고 `check_pass.py`로 판정한다.
3. 수정하면 `report-v(N+1).json`을 새로 만든다. 이전 버전 파일은 지우지 않는다.
4. 통과하거나 중단 조건에 해당하면 `status`와 `review.rounds`를 채운 최종 `report.json`을 만들어 렌더링한다.

## 렌더러가 강제하는 것

- `status`가 `통과`이려면 마지막 라운드가 최종 `version`을 평가했고, 반올림 전 평균이 목표 이상이며, 미해결 차단·중대 지적이 0이어야 한다. 아니면 렌더링을 거부한다. 반대로 통과 조건을 만족하는데 `통과`가 아니어도 거부한다.
- 모든 라운드에서 리뷰어 집합이 `review.reviewers`와 같아야 한다.
- 근거는 존재하는 출처 ID를, 시사점은 존재하는 근거 ID를 가리켜야 한다. 구분은 `사실 / 해석 / 가정 / 합성 예시` 중 하나다.
- 미통과 보고서에는 "잠정 결과" 문구가 자동으로 붙는다.
- 모든 텍스트는 HTML 이스케이프된다.

## report.json 스키마

```
title, date, status(통과|추가 입력 필요|기준 미달), version, question,
conclusion[문단...],
sources[{id,title,locator,date,status}],
evidence[{id,source,claim,type,location,scope,limit}],
benchmark?{why, rows[{name,value,basis,evidence[],comparable}]},
implications[{text,evidence[],conditions,alternatives,questions}],
unverified[문장...],
review{method,target,max_rounds,reviewers[],
       rounds[{round,version,scores{Red 1:점수,...},open_blocking_or_major}],
       changes[], remaining[], end_reason}
```

점수는 소수 첫째 자리까지만 허용한다. 최종 보고서의 `rounds`에는 모든 라운드를 남기되 판정은 마지막 라운드만 사용한다.
