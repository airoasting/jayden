---
name: dev-workflow
description: "명시적인 dev-workflow 호출이나 분담형·sub-agent 위임 요청에서 개발 단계·계획 승인·독립 리뷰를 조율한다. 일반 개발 요청의 기본은 dev-workflow-simplify다."
---


일반 개발 요청에는 [dev-workflow-simplify](../dev-workflow-simplify/SKILL.md)를 기본으로 사용한다. 이 skill은 사용자가 `$dev-workflow` 또는 `/dev-workflow`를 명시 호출하거나 분담형·sub-agent 위임을 요청한 범위에만 적용한다. 단순 계획·리뷰·수정 요청만으로 분담형으로 전환하지 않는다. 명시적 전환 요청 전까지 선택한 모드를 유지한다.

사용자가 요청한 단계에 맞는 skill을 선택한다. Routine은 직접 수행하며 전체 인터뷰·리뷰를 강제하지 않는다. Codex에서는 `$dev-workflow`, Claude Code에서는 `/dev-workflow`로 명시 호출할 수 있다. 여러 단계 요청은 메인이 조율하고 단일 단계 요청은 해당 skill만 사용한다.

| 단계 | skill | 담당 |
|---|---|---|
| Repo Check | [dev-repo-check](../dev-repo-check/SKILL.md) | repo_explorer |
| Plan | [dev-plan](../dev-plan/SKILL.md) | 메인·planner |
| 인터뷰 의도 점검 | [dev-intent-review](../dev-intent-review/SKILL.md) | intent_reviewer |
| Plan Review | [dev-plan-review](../dev-plan-review/SKILL.md) | 메인·네 reviewer |
| Code | [dev-code](../dev-code/SKILL.md) | implementer |
| Code Review | [dev-code-review](../dev-code-review/SKILL.md) | 메인·네 reviewer |

이 skill의 호출은 단계 전환·사용자 승인·리뷰 방식 선택을 대신하지 않는다. `$dev-plan`이나 `/dev-plan` 호출만으로 구현 승인으로 해석하지 않는다. 기존 채팅의 명시적 승인·생략 지시는 재사용한다.

모델·추론은 agent 설정에서 관리한다. 메인 Coordinator는 사용자가 앱에서 선택하며, 이 skill은 메인 모델을 변경하지 않는다. 현재 Codex 역할의 Sol 설정과 Claude의 model inherit를 유지한다.

skill은 자연어 절차다. 호출 가능한 형식과 실제 런타임 인식·위임 성공을 구분한다. Codex `.agents/skills`와 Claude `.claude/skills`의 현재 적용본을 사용하며, `잡동사니`의 보관본·배포본을 자동 검색해 대체하지 않는다.

# 개발 워크플로 조율

## 위치와 진행 기록
메인은 workflow root(현재 skill 묶음과 루트 AGENTS.md 또는 CLAUDE.md를 포함하는 프로젝트 폴더)와 실제 target root를 구분한다. target root의 적용 지침을 확인하여 인계한다. dev 자체가 Git 저장소라고 가정하지 않는다.
작업별 기록에는 단계, target root, 조사 결과, 인터뷰 라운드, 요구사항 버전·사용자 확인 근거, 계획 버전·리뷰 방식·승인 근거, 코드 검토 대상, 재검토 횟수, 편집 소유권, 다음 대기 조건을 남긴다. 현재 채팅 기록도 근거가 된다.
파일 기록이 필요하면 대상별 작업 위치와 task-id를 정하고 [인계 양식](references/templates/handoff.md)을 사용한다. 사용자가 양식을 채워야 시작할 수 있다는 조건을 만들지 않는다.

## Routine
질의응답, 아키텍처 자문, 작은 수정·Bugfix는 직접 처리한다. 규모 있는 변경이나 Clarification 때문에 Plan 승격이 필요하면 이유를 설명하고 승인 후 전환한다. 작은 수정에 3라운드 인터뷰·4개 관점 리뷰를 강제하지 않는다.

## Repo Check
계획 전에 repo_explorer로 구조, 실행 경로, 호출부, 테스트 방법과 적용 지침을 조사한다. 같은 세션·같은 대상의 조사 결과는 재사용한다. 대상이 바뀌면 새 대상의 필요한 부분을 조사한다. 조사 전에 요구사항 질문을 시작하지 않는다. 없는 테스트 도구·명령을 만들어내지 않는다.

## Plan: Deep Interview
제품 코드 수정 없이 메인이 질문하고 planner가 질문 후보·결정 기록을 보조한다.
1. 서로 겹치지 않는 질문 영역으로 최소 3라운드 수행한다. 예: 목표·범위, 동작·계약, 검증·제약. 기존 답은 재사용하고 같은 질문을 반복하지 않는다.
2. [인터뷰 기준](references/interview.md)에 따라 확정 / 위임됨 / 제안된 가정 / 미확정·충돌을 기록한다.
3. 종료 후보에서 intent_reviewer와 verification_reviewer를 독립 실행한다. Planner 자신의 종료 선언은 독립 점검을 대신하지 못한다.
4. 중요 미확정 사항은 사용자 질문 또는 repo_explorer 조사로 해소하고 영향받는 결정만 재점검한다. 같은 쟁점이 반복되면 해석별 결과·선택지를 제시하며 자동 종료하지 않는다.
5. 메인이 목표·범위·보존 동작·성공 조건·위임 범위를 요약하여 사용자 확인을 받는다. 미응답·시간 경과는 확인이 아니다.

## Plan: 작성과 승인
요구사항 확인 후 planner가 [계획 양식](references/templates/plan.md)의 필수 항목을 작성한다. 메인이 초기 계획을 제시하고 직접 리뷰 / sub-agent 리뷰 선택을 기다린다. 자동 리뷰나 구현을 하지 않는다.
리뷰 반영 후 최종 계획에 대해 명시적 승인·실행 지시를 확인한다. 다른 세션의 Plan Review는 사용자가 제공한 계획을 대상으로 한다. 계획 작성자를 자기 계획의 독립 리뷰어로 사용하지 않는다.
사용자가 리뷰 생략과 해당 계획 실행을 명시하면 근거를 기록하고 실행한다. 해당 작업의 예외이며 후속 작업의 기본 절차를 변경하지 않는다.

## Plan Review
sub-agent 리뷰 선택 시 structure_reviewer, stability_reviewer, verification_reviewer, performance_reviewer의 4개 관점을 수행한다. Plan에서 제품 코드 수정·테스트 작성은 금지한다. 실제 코드를 읽고 검증 필요성과 계획을 검토한다.
[리뷰 기준](references/review.md)으로 Blocking / Critical / Detail / Test 보완을 통합한다. 문제가 없으면 채팅에 근거를 반환하고 빈 리뷰 문서를 강제하지 않는다. Planner가 지적을 반영하며 부적절한 제안은 근거와 함께 기각한다.
새 모호함은 관련 결정을 사용자와 확인하고 계획을 갱신한다. 수정 뒤 재검토 횟수를 유지하며 최종 승인 전 Code로 진행하지 않는다.

## Code
implementer에게 승인 계획 버전·승인 근거·확정 결정·target root를 전달한다. 구현 직전에 대상 구조·관련 상태를 재확인하고 지정 파일만 수정한다. Repo Check 전체를 반복하지 않는다.
계획 밖 구현은 영향받는 작업을 멈추고 충돌·필요 결정·대안을 메인에게 보고한다. 사용자 결정을 임의로 확정하지 않는다. 코드·중요 함수에는 목적 주석을 작성한다.
실제 프로젝트 검증 명령으로 결과·한계·미검증을 인계한다. 다른 작성자의 변경을 되돌리지 않는다.

## Code Review와 수정
4개 관점이 같은 고정 코드 상태를 검토한다. 검토 중 변경이 생기면 영향받는 결과를 낡은 것으로 표시하고 다시 확인한다.
취합 전 제품 코드 수정은 금지한다. 테스트 추가는 메인이 테스트 경로 소유권을 지정한 뒤 수행한다. 공유 상태를 바꾸는 검증은 순차 실행한다.
취합 후 메인이 implementer 또는 리뷰어에게 수정 단계·허용 파일·발견 사항 ID를 지정한다. 작은 수정·추가 테스트는 이 범위에서 허용한다. 수정자는 자신이 작성한 변경의 유일한 독립 승인자가 될 수 없다.
최초 리뷰 이후 최대 3회 수정·재검토한다. 중요 문제가 남거나 범위 확대가 필요하면 사용자 판단을 요청한다. 필수 미검증·차단 사항이 남은 결과를 완료·통과로 표시하지 않는다.

## 위임과 환경 지원
[역할 매핑](references/roles.md)과 [인계 양식](references/templates/handoff.md)을 사용한다. 역할명, 공통 절차·역할 참조의 절대 경로, 최소 원본 근거를 전달한다. 리뷰어에게 작성자의 통과 선언만 전달하지 않는다.
Custom agent 이름이 실제 로딩되는지 확인한다. 역할 직접 선택이 없지만 일반 sub-agent 도구가 있으면 역할 지침을 명시한 별도 sub-agent로 실행하고 실제 방식을 보고한다. 위임 자체가 불가능하면 메인 순차 적용 가능 여부를 사용자에게 알리며 독립 검토를 대체했다고 주장하지 않는다.
4개 관점은 논리적으로 독립적이다. 슬롯이 3개이면 3개 실행 후 남은 1개를 슬롯 확보 후 실행한다. 설정으로 플랫폼 한도를 높였다고 주장하지 않는다.
