# 마선생 Masense — 앱 빌딩 준비 문서

2026-10-13 아이디에이션 문서를 실제 개발용 사양으로 풀어낸 세트입니다. `CLAUDE.md`는 Xcode 프로젝트 루트에, 나머지는 `docs/`에 두고 Claude Code로 작업을 시작하는 것을 전제로 작성했습니다.

## 파일 구성

| 파일 | 역할 | 주 독자 |
|---|---|---|
| `CLAUDE.md` | Claude Code가 세션마다 읽는 프로젝트 규약. 스택, 네이밍, 금지선, 작업 순서 | Claude Code |
| `PRD.md` | 제품 요구사항. 비전, 사용자, 범위(MVP / v1.1), 하지 않을 것, 성공 지표 | 사람 + Claude Code |
| `DATA_MODEL.md` | SwiftData 모델, 관계, HealthKit 매핑, 마이그레이션 원칙 | Claude Code |
| `SCREENS.md` | 화면 목록, 내비게이션 구조, 화면별 요소와 상태, 유저 플로우 | Claude Code + 디자인 |
| `RULES.md` | 비즈니스 로직 규칙. 카운트다운, 컨디션 체크 윈도우, 감량 속도 안내, 단백질 목표 계산 등 | Claude Code |
| `REPORT_SPEC.md` | 진료 전 리포트 PDF의 레이아웃·데이터·생성 규칙 | Claude Code + 디자인 |
| `DESIGN_SYSTEM.md` | 색·타이포·간격 토큰, 글래스 카드 스타일, 컴포넌트 목록 | Claude Code + 디자인 |
| `COMPLIANCE.md` | 의료 경계선, 문구 가이드, 면책, App Store 심사 체크리스트, 상표 확인 | 사람 |
| `MILESTONES.md` | 빌드 순서, 마일스톤별 완료 기준, 작업 분해 | 사람 + Claude Code |

## 사용 순서

1. `COMPLIANCE.md`의 "출시 전 확인" 항목(상표 검색, 명칭 검토)을 먼저 해소합니다.
2. Xcode에서 빈 SwiftUI 프로젝트를 만들고 이 폴더를 루트에 둡니다.
3. Claude Code를 열고 `MILESTONES.md`의 M0부터 순서대로 진행합니다.
4. 사양이 바뀌면 코드가 아니라 문서를 먼저 고칩니다. 문서가 단일 진실 원천입니다.

## 용어 통일

| 용어 | 영문 식별자 | 의미 |
|---|---|---|
| 마디 | `Cycle` | 투약 1회를 기준으로 한 주 단위 |
| 투약 | `Dose` | 주사 1회 기록 |
| 컨디션 체크 | `ConditionCheck` | 투약 후 48시간 내 증상 기록 |
| 리포트 | `ClinicReport` | 진료 전 PDF 한 장 |
| 단백질 채우기 | `ProteinEntry` | 끼니별 단백질 식품 체크 |
| 근력운동 마디 | `StrengthSession` | 근력운동 1회 기록 |
| 처방 | `Prescription` | 펜 수·회차·다음 진료일 묶음 |
