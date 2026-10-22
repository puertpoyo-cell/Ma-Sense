# MILESTONES — 빌드 순서

Claude Code는 매 세션 이 파일에서 현재 위치를 확인하고, 완료한 항목의 체크박스를 갱신합니다. 한 마일스톤 안에서는 위에서 아래 순서로 진행합니다.

## M0 — 뼈대 (0.5주)

완료 기준: 빈 앱이 빌드·실행되고, 테스트 타깃이 돌고, 디자인 토큰이 보인다.

- [x] Xcode 프로젝트 `Masense` 생성 (iOS 17, SwiftUI, SwiftData 체크 해제 후 수동 구성)
- [x] `CLAUDE.md` 폴더 구조대로 그룹 생성
- [x] `DesignSystem/` 토큰 (`Color+Tokens`, `Spacing`, `Typography`), `FrostCard`, `PrimaryButton`, `RecordedToast`
- [x] `App/MasenseApp.swift` — `ModelContainer` 구성 (SchemaV1), 다크 고정
- [x] `Localizable.xcstrings` 생성, `COMPLIANCE.md` 3.2 고정 문구 등록
- [x] `MasenseTests` 타깃, 더미 테스트 1개 통과
- [x] 탭 3개 빈 화면 + 설정 push
- [x] GitHub Actions CI (`.github/workflows/ci.yml`, macOS 러너 `xcodebuild test`)

## M1 — 투약 루프 MVP (2~3주)

완료 기준: 온보딩 → 투약 기록 → 컨디션 체크 → 리포트 PDF까지 한 바퀴가 돈다. TestFlight 1차.

### M1-a 모델·규칙
- [x] `Models/` SchemaV1 5개 모델 (`DATA_MODEL.md`)
- [x] `Rules/CycleRules.swift` R1·R2·R3 + 테스트 (`Rules/Snapshots.swift`, `Models/Snapshots+Models.swift` 포함)
- [x] `Rules/NotificationRules.swift` R4 + 테스트
- [x] `Rules/ConditionRules.swift` R5 + 테스트
- [x] `Rules/SiteRules.swift` R6 + 테스트
- [x] `Rules/WeightRules.swift` R7 + 테스트
- [x] `Rules/PrescriptionRules.swift` R13 + 테스트

### M1-b 서비스
- [x] `NotificationService` — 권한, 4주 재등록, Dose 기록 시 취소 (`NotificationCoordinator`가 저장 데이터 → R4 → 등록)
- [x] `HealthKitService` — 권한, `bodyMass` 읽기, 캐시 upsert (`WeightSyncService`, 프로토콜 + Fake)
- [x] `StoreService` — StoreKit 2 비소모성 1종, 복원 (프로토콜 + Fake)
- [x] HealthKit capability(entitlement) + `NSHealthShareUsageDescription` 추가 — 2026-10-22 사용 결정, D3-a
- [x] StoreKit 상품 ID 확정 — `com.masense.pro` 유지 (2026-10-22 사람 결정)
- [ ] 로컬 구매 테스트용 `.storekit` 구성 파일 — App Store Connect에 상품을 만든 뒤 Xcode에서 "Sync this file with an app in App Store Connect"로 생성 (가격·이름이 ASC 값을 따른다). 스킴 Run > Options > StoreKit Configuration에 지정 — 사람
- [ ] 번들 ID 확정 (현재 `com.masense.Masense`) — Xcode Signing에서 팀 선택 시 함께

### M1-c 화면
- [x] S0 온보딩 4페이지 (HealthKit 버튼은 Info.plist 키 추가 전까지 숨김)
- [x] S9 PrescriptionSheet (`PrescriptionFormModel` + 테스트, 홈 빈 상태에서 열기)
- [x] `AppServices` DI (live/fake), 포그라운드 진입 시 알림 재등록
- [x] S1 TodayView: 1-1 카운트다운, 1-2 컨디션, 1-3 체중, 1-5 진료 (`TodayModel` + 테스트, `WeekSparkline`)
- [x] S2 DoseLogSheet + `BodyMapView` (`DoseLogModel` + 테스트)
- [x] S3 ConditionCheckSheet (`ConditionCheckModel` + 테스트, `SymptomChip`)
- [x] S4 HistoryView 투약·컨디션·체중 (`HistoryModel` + 테스트, 누락 행에서 과거 기록, 지난 컨디션 체크, `WeekChart`)
- [x] S6 SettingsView 처방·알림·연동·구매·데이터·정보 (`DataExportService` + 테스트). 리포트 섹션(테마·기본 기간)은 M1-d에서
- [x] WeightEntrySheet (`WeightEntryModel` + 테스트)

### M1-d 리포트
- [x] `Rules/ReportBuilder.swift` — `ClinicReport` 생성, 섹션 A~E·G·H + 테스트 (R12 기간 포함, 스냅샷 대신 값 비교)
- [x] `ReportView` 미리보기 (SwiftUI, 라이트 강제) — `ReportPage`(A4 고정 크기) + `ReportPreviewView`(폭 맞춤 축소)
- [x] `ReportRenderer` — `ImageRenderer` → PDF, `ShareLink` (PDFKit으로 A4 1장 검증)
- [x] 구매 게이트 (`ReportPurchaseSheet`)
- [x] 리포트 기본 기간을 설정에 저장 — 2026-10-22 결정, D3-b (SchemaV3)
- [ ] 실기기에서 12주·증상 10개·메모 5줄 리포트가 A4 한 장에 들어가는지 육안 확인 (높이 계산은 D2-a 테스트로 확인, 넘침 안내는 D2-a)

### M1-e 마감
- [x] 접근성 점검 — 코드 수준 (VoiceOver 레이블·토글 특성, AX 크기에서 가로→세로 `AdaptiveStack`, 온보딩 스크롤+버튼 고정)
- [ ] 접근성 실기기 확인 (VoiceOver 한 바퀴, 설정 > 손쉬운 사용 > 더 큰 텍스트 최대) — 사람
- [x] `COMPLIANCE.md` 2.1 금지선 전수 확인 — `scripts/compliance_check.py` + CI job, 기록은 COMPLIANCE.md 8
- [x] 개인정보 처리방침 초안 (`docs/PRIVACY.md`, 게시용 `docs/privacy/index.html`)
- [ ] 처리방침 게시·URL 입력 (`AppConfig.privacyPolicyURL`), 시행일·문의 이메일 채우기 — 사람
- [x] 베타 안내문·빌드 절차 (`docs/TESTFLIGHT.md`, 역할·연령 고지 포함)
- [ ] TestFlight 빌드 업로드 (번들 ID·서명·IAP 상품·HealthKit 결정 후) — 사람

## M2 — 근육 지키는 감량 (2주)

완료 기준: 단백질·운동 기록이 홈과 리포트에 반영된다. TestFlight 2차.

### M2-a 모델·규칙
- [x] SchemaV2 + `SchemaMigrationPlan` (V1 → V2 경량) — 디스크 저장소 마이그레이션 테스트 포함
- [x] `ProteinEntry`, `StrengthSession`, `HabitCheck` (내보내기·전체 삭제에도 포함)
- [x] `Rules/ProteinRules.swift` R9·R10 + 테스트
- [x] `Rules/StrengthRules.swift` R11 + 테스트
- [x] `Rules/PaceRules.swift` R8 + 테스트
- [x] `isLowConditionDay` 공용 함수 (`ConditionRules`)

### M2-b 화면
- [x] S1 1-4 오늘의 마디 카드 (끼니 4칸 `MealSlotRow`, 단백질 상태, 이번 주 운동 사실, 수분·식이섬유·수면 체크)
- [x] S7 ProteinSheet (식욕 저하일 모드 포함, `ProteinLogModel` + 테스트)
- [x] S8 StrengthSheet (저컨디션 순서, 예시 루틴 접힘, `StrengthLogModel` + 테스트)
- [ ] 예시 루틴 문구(`exercise.routine.*`) 검토 — 일반 건강관리 정보 범위인지 사람 확인 (COMPLIANCE.md 2.2)
- [x] S4 습관 세그먼트 캘린더 (`HistoryModel.habitMonth` + 테스트, 모양으로 구분)
- [x] S6 단백질 설정 섹션 (목표는 직접 입력, 앱이 기본값 제안 안 함)
- [x] 1-3 체중 카드에 `paceNotice`
- [x] 감량 속도 안내 출처 `AppConfig.paceGuideSource = "pace.source"` (CDC, 2026-10-22, D3-c)
- [x] 단백질 권고 범위 출처 `AppConfig.proteinGuideSource = "protein.source"` (2025 공동 권고문, D3-d)

### M2-c 리포트·연동
- [x] `ReportBuilder` F 섹션 (단백질 채운 날/기록·평균, 근력운동 횟수, 제지방량 시작→현재, 데이터 없으면 생략) + 테스트
- [x] `HealthKitService` `leanBodyMass` 읽기 (같은 날 HealthKit 체중 샘플에 붙임) + 테스트
- [x] (P2) HealthKit workout → StrengthSession 자동 인식 (`WorkoutSyncService`, upsert·삭제 반영) + 테스트
- [x] 리포트 테마 3종 (`accent` 교체, 설정에서 구매 후 선택)

### M2-d 마감
- [x] 금지선 재확인 (판단어 grep: 좋음, 부족, 충분, 성공, 달성) — `scripts/compliance_check.py`, 기록은 COMPLIANCE.md 8
- [ ] TestFlight 2차 — 사람

## D1 — 디자인 시스템 Blueprint Edition 적용 (2026-10-21)

> 실기기·시뮬레이터 육안 확인(도면 셀 정렬, 교차점 마커 위치, 큰 글자)은 사람 확인 대기 표 10번에 포함

완료 기준: DESIGN_SYSTEM.md(Blueprint Edition)의 토큰·컴포넌트가 기존 화면에 반영되고 기존 테스트가 그대로 통과한다.

- [x] DESIGN_SYSTEM.md 교체·정리 (초안과 코드 차이는 8절), SCREENS 1-1·RULES R6·R10·R11 동기화
- [x] 토큰: `frostHighlightTop/Bottom`, `gridHairline`, `gridCrosshair`, `paper*`, `siteRecent` 1.0/0.45/0.35/0.25, `metricLarge`, `sectionHeader`
- [x] `FrostCard` 하이라이트 그라데이션 보더 + 등장 모션, `BlueprintDivider`·`BlueprintCell`·`BlueprintSplit`, `DimensionValue`
- [x] `CountdownHero` 하이브리드 (24시간 기준 D-n / D-Day + 시간·분, D+n, 우측 예정 시간·회차 셀)
- [x] 홈 카드 도면 셀화 (체중, 오늘의 마디)
- [x] `BodyMapView` 직전 1회 강조 + "① 마지막 / ② 이전" 이력 행
- [x] `SymptomChip` 0|1|2|3 세그먼트 트랙, 심각도 3 볼드 + 하이라이트 테두리
- [x] R10 `isLowAppetiteDay` / R11 `isLowConditionDay` 분리
- [x] 시트 detent·그래버, `RecordedToast` 햅틱, 스파크라인 눈금 4pt, `MealSlotRow` 8pt, `WeekChart` y축 최소·최대
- [x] 리포트 라이트 토큰(`paper*`), 금지 아이콘 점검(`pills`, `scalemass`, `exclamationmark.triangle`) 추가

## D2 — 남은 사양 공백과 Blueprint 확장 (2026-10-22)

완료 기준: 사양에 있으나 비어 있던 동작을 채우고, 홈 밖 화면(기록 탭·설정·시트)도 DESIGN_SYSTEM.md 1·5.1을 따른다. 기존 테스트는 그대로 통과한다.

- [x] D2-a 리포트 넘침 안내 (REPORT_SPEC 형식): `ReportPage.Layout.measure`로 자연 높이를 재서 A4를 넘으면 미리보기 아래 `NoticeLine` "기간을 줄이면 한 장에 들어갑니다". D·E 줄은 60mm 이상, 부작용 표가 길면 표 높이를 따라 늘고 아래 칸과 겹치지 않는다. 12주 상한 리포트가 한 장에 들어가는지 테스트
- [x] D2-b 기록 탭: `.frostRow()`(행 구분선 `gridHairline`), 섹션 헤더 `label`, 체중 차트 투약일 눈금(`WeightRules.doseTicks`, 홈과 공용) + 샘플 수치 `DimensionValue`, 습관 캘린더 `BlueprintGridLines`
- [x] D2-c 설정·시트: `FormStyle.swift`(`.frostRow()`, `SectionHeaderText`)를 설정, 처방·투약·체중·운동 시트에 적용. 기본 회색 행 배경이 남던 투약·체중·처방 폼도 `frost`로

## D3 — 사람 결정 반영 (2026-10-22)

- [x] D3-a HealthKit 읽기 연동: entitlement, `NSHealthShareUsageDescription`(ko/en), 금지선 점검이 권한 문구도 본다
- [x] D3-b 리포트 기본 기간 저장: SchemaV3(`UserSettings.reportDefaultPeriod`), V1·V2 `UserSettings` 고정 사본, R12 `defaultPeriod(saved:…)`, 설정 > 리포트 "기본 기간", 마이그레이션 테스트 V2 → V3
- [x] D3-c 감량 속도 안내: CDC 주 0.5~1 kg 기준으로 R8을 kg 단위로 바꾸고 표시(`pace.source`). 문구는 "일반적인 권장일 뿐 사람마다 다를 수 있으니 의사와 상의하세요"로 끝낸다
- [x] D3-e 앱 아이콘 1차안 "유리 막대 M" — 단색 바탕, 캡슐형 유리 막대 4개 M + 뒤의 accent 구 (`scripts/make_app_icon.py` → `AppIcon.png`, 대안 `ma`·`hangul`, DESIGN_SYSTEM.md 6)
- [x] 시뮬레이터 스크린샷으로 찾은 버그: 바디맵 실루엣·구역이 캔버스 밖으로 밀림(정렬 기준 누락), 예정 시간 "(금요일)" 괄호
- [x] D3-f 시뮬레이터 스크린샷 워크플로 (`screenshots.yml`, `[shots]` 커밋 또는 수동 실행, DEBUG `-route`)
- [x] D3-d 단백질 권고 범위 표시: 출처 2025 공동 권고문(감량 중 1.2~1.6 g/kg/일 제안, 일반 성인 기준 0.8 g/kg, 하루 2 g/kg 초과 지속은 피함). `protein.guide`에 "감량 중"을 밝히고 "의사와 상의하세요"로 끝낸다

## M3 — 출시 준비 (1주)

- [ ] `COMPLIANCE.md` 6 출시 전 확인 전부 — 사람
- [x] 스크린샷 가이드·예시 데이터 (`docs/APP_STORE.md` 2, `SampleData` + `-seedSampleData`)
- [ ] 스토어 스크린샷 촬영 (약물명·용량 없음) — 사람
- [x] 스토어 설명 초안 (COMPLIANCE 4.5 방향, `docs/APP_STORE.md` 1)
- [ ] 연령 등급 설문 — 사람 (`docs/APP_STORE.md` 4)
- [ ] 심사 제출 — 사람 (심사 메모 초안 `docs/APP_STORE.md` 5)

## 사람 확인 대기 (한곳에 모음)

코드는 아래 값이 정해지기 전에도 동작하도록 해 두었다. 정해지면 표시된 곳만 바꾸면 된다.

| # | 항목 | 바꿀 곳 | 정하기 전 동작 |
|---|---|---|---|
| 1 | 번들 ID·서명 팀 | Xcode Signing (현재 `com.masense.Masense`) | 시뮬레이터·CI는 서명 없이 동작 |
| 2 | ~~인앱 구매 상품 ID~~ — **결정: `com.masense.pro` 유지 (2026-10-22)**. App Store Connect에 같은 ID로 비소모성 상품 생성 필요 | `StoreService.productID` | 상품을 못 불러오면 구매 버튼이 안 보임, 복원 버튼만 |
| 3 | ~~HealthKit 사용~~ — **결정: 사용 (2026-10-22), D3-a 반영** | `Config/Masense.entitlements`, `INFOPLIST_KEY_NSHealthShareUsageDescription`, `InfoPlist.xcstrings` | — |
| 4 | 개인정보 처리방침 게시 URL·시행일·문의 이메일 | `AppConfig.privacyPolicyURL`, `docs/privacy/index.html` | 설정에 처리방침 링크 숨김 |
| 5 | ~~단백질 권고 범위 출처~~ — **결정: 표시 (2026-10-22), D3-d 반영.** 2025 공동 권고문(ACLM·ASN·OMA·TOS, Obesity 2025, doi:10.1002/oby.24336; AJCN 판 PMC12264624) "감량 중 1.2~1.6 g/kg/일" | `protein.source`, `protein.guide` | — |
| 6 | ~~감량 속도 출처~~ — **결정: CDC 주 0.5~1 kg 기준으로 표시 (2026-10-22), D3-c 반영** | `pace.notice`, `pace.source`, `PaceRules.weeklyChangeThresholdKg` | — |
| 7 | 맨몸 예시 루틴 문구 검토 | `Localizable.xcstrings`의 `exercise.routine.*` | 초안 그대로 표시 (일반 건강관리 정보 고지와 함께) |
| 8 | ~~리포트 기본 기간 저장~~ — **결정: 저장 (2026-10-22), D3-b 반영** | `UserSettings.reportDefaultPeriod`, SchemaV3 | — |
| 9 | 앱 이름·부제·아이콘 (브랜딩 논의) — 아이콘 1차안 "유리 막대 M" 적용 (2026-10-22), 대안 "Ma"·"마" | 스토어 문구, `INFOPLIST_KEY_CFBundleDisplayName`, `scripts/make_app_icon.py` | 작업명 "마선생", 아이콘 1차안 |
| 10 | 실기기 확인: VoiceOver, 최대 글자 크기, 12주 리포트 A4 한 장 | — | — |
| 11 | COMPLIANCE.md 6 출시 전 확인 (상표·명칭·가이드라인) | — | — |

## 작업 분해 규칙

- 한 작업 = 한 PR 크기 (파일 5개 내외, 테스트 포함)
- `Rules/` 작업은 반드시 테스트 먼저
- 화면 작업은 `#Preview`에 in-memory 컨테이너 + 샘플 데이터
- 작업을 마치면 이 파일의 체크박스를 켜고, 새로 발견한 작업은 해당 마일스톤 끝에 추가

## 결정 로그

| 날짜 | 결정 | 근거 |
|---|---|---|
| 2026-10-13 | 서버 없음, 온디바이스 전용 | 건강 데이터 신뢰, 운영 부담 제거 |
| 2026-10-13 | 평생 구매 1종, 구독 없음 | 건강 앱 신뢰 |
| 2026-10-20 | 투약 간격을 `intervalDays`로 모델링, UI는 주 1회만 | v2 확장 대비, 스키마 변경 회피 |
| 2026-10-20 | `doseLabel`은 자유 메모, 앱이 해석 안 함 | 용량 판단 금지선 |
| 2026-10-20 | 빨강·초록 색 금지 | 판단하지 않는 원칙의 시각화 |
| 2026-10-22 | 인앱 구매 상품 ID `com.masense.pro` 유지 | 사람 결정. 비소모성 1종 구성 그대로 |
| 2026-10-22 | HealthKit 읽기 연동 사용 (체중·제지방량·운동) | 사람 결정. 쓰기는 하지 않음 |
| 2026-10-22 | 리포트 기본 기간을 설정에 저장 (SchemaV3, 경량 마이그레이션) | 사람 결정. 바뀐 모델은 이전 버전에 고정 사본 |
| 2026-10-22 | 감량 속도 안내 기준을 주 1%에서 주 1 kg(CDC 주 0.5~1 kg 상한)으로 | 사람 결정. % 기준은 확인 가능한 공식 출처가 없음 |
| 2026-10-22 | 단백질 권고 범위 1.2~1.6 g/kg 표시, 출처 2025 공동 권고문 | 사람 결정. 원문 문장 확인(검색 발췌, AJCN 판) |
| 2026-10-21 | `Prescription.scheduledTime`은 `scheduledHour`·`scheduledMinute` Int 2개로 저장, `DateComponents`는 계산 속성 | SwiftData Codable 저장 안정성 |
| 2026-10-21 | Xcode 16 폴더 동기화 그룹 + GitHub Actions macOS CI | Xcode 없는 환경(Claude Code 클라우드)에서도 파일 추가·검증 가능 |
| 2026-10-21 | 단위 테스트는 Swift Testing | iOS 17+/Xcode 16 기준, 선언적 `#expect` |
