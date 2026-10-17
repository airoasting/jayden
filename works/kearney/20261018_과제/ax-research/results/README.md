# results/

실행 결과를 저장하는 폴더다. **저장을 요청받았거나 작업 범위에 포함된 경우에만** 사용한다. 사용자가 다른 위치를 지정하면 그곳을 따른다.

## 실행 폴더 구조

실행 한 번당 폴더 하나를 만든다: `results/<YYYY-MM-DD>-<주제-슬러그>/`

```
results/2026-10-17-example-topic/
├── run-config.md        # 질문, 독자, 범위, Red 구성, 목표 9.5, 최대 라운드, 검토 방식
├── source-register.md   # templates/source-register.md 복사본
├── evidence-ledger.md   # templates/evidence-ledger.md 복사본
├── drafts/
│   ├── v1.md
│   └── v2.md            # 통과 후 내용을 바꾸면 새 버전으로 저장
├── reviews/
│   ├── round-1-red-1.md # templates/review-report.md 형식
│   ├── round-1-red-2.md
│   └── round-1-red-3.md
├── revisions/
│   └── v1-to-v2.md      # templates/revision-log.md 형식
├── rounds/
│   └── round-1.json     # scripts/check_pass.py 입력
└── final-report.md      # templates/final-report.md 형식
```

## 규칙

- 원본 자료는 이 폴더에 덮어쓰지 않는다. 필요하면 `inputs/`에 복사본을 둔다.
- 과거 라운드 파일은 지우지 않는다. 판정은 최신 라운드 점수만 사용한다.
- 통과 판정은 `python3 scripts/check_pass.py results/<실행폴더>/rounds/round-N.json`으로 재확인한다.
- 민감한 자료를 저장할 때는 사용자 허락을 받는다.
