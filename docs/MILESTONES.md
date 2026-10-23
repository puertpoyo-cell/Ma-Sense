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
- [x] 번들 ID 확정 — `com.masense.app` (테스트 `com.masense.app.tests`), 2026-10-22 사람 결정
- [x] 서명 팀 선택 — Xcode Signing & Capabilities (2026-10-22 사람 지정, `DEVELOPMENT_TEAM`)
- [x] `Rules/ExportCodec.swift` + `ExportService` — 내보내기·가져오기 (`EXPORT_FORMAT.md`), round-trip 테스트 + fixture (main E, D4-E1)
- [x] Info.plist `UTExportedTypeDeclarations` (`.masense.json`) — `Config/Masense-Info.plist` (main E, D4-E2)

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
- [x] 처리방침 게시·URL 입력 (`AppConfig.privacyPolicyURL` = https://masense-privacy.vercel.app/), 시행일 2026-10-30·문의 이메일 (2026-10-22)
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
- [x] D3-e 앱 아이콘 1차안 "겹친 유리 M" — Apple 기본 앱 유리 문법 참고, 사람 선택(B안, 막대 굵기 136). 밝은 바탕, 하늘·보라·파랑·남색 반투명 캡슐 막대 4개가 겹쳐 섞이는 M (`scripts/make_app_icon.py` → `AppIcon.png`, 대안 `liquid`·`rings`, DESIGN_SYSTEM.md 6)
- [x] 시뮬레이터 스크린샷으로 찾은 버그: 바디맵 실루엣·구역이 캔버스 밖으로 밀림(정렬 기준 누락), 예정 시간 "(금요일)" 괄호
- [x] 2차 스크린샷으로 찾은 것: 체중 차트 투약일이 전체 높이 점선이던 것을 4pt 눈금으로(사양 5.5), 습관 캘린더가 접근성 최대 글자에서 숫자가 두 줄로 쪼개지던 것 (격자만 글자 크기 상한 accessibility1)
- [x] D3-f 시뮬레이터 스크린샷 워크플로 (`screenshots.yml`, `[shots]` 커밋 또는 수동 실행, DEBUG `-route`)
- [x] D3-d 단백질 권고 범위 표시: 출처 2025 공동 권고문(감량 중 1.2~1.6 g/kg/일 제안, 일반 성인 기준 0.8 g/kg, 하루 2 g/kg 초과 지속은 피함). `protein.guide`에 "감량 중"을 밝히고 "의사와 상의하세요"로 끝낸다

## D4 — main 사양 A~E 코드 반영 (2026-10-22 통합)

main에서 따로 정한 문서 변경 A~E(2026-10-21)를 이 브랜치 문서에 합쳤다. 문서가 진실 원천이므로 아래 코드 작업이 남는다. 스키마 변경(B·C)은 출시 전 재정리로 한 번에 처리했다.

- [x] A. App Groups capability `group.com.puertpoyo.masense` + 스토어를 App Group 컨테이너 경로에 (`StoreLocation`, `ModelContainer+Masense`), 테스트·미리보기는 in-memory 그대로. 기존 기본 경로 스토어가 있으면 첫 실행에 옮김 (D4-A). 실기기 서명·기록 유지 확인은 사람 (사람 확인 대기 표 11번)
- [x] B. CloudKit 호환 스키마: `@Attribute(.unique)` 제거, 모든 저장 속성에 기본값 또는 옵셔널, 열거형 `xxxRaw` 저장 + 계산 프로퍼티. 출시 전이라 V1~V3 이력을 접고 새 `SchemaV1` 하나로 재정리 (2026-10-22 사람 결정, D4-a). `SchemaTests`
- [x] C-1. `Prescription.endDate` + 새 처방 시작 시 이전 처방 `endDate`(= 새 시작일 전날)·`isActive` 갱신 (`Prescription.activate`, D4-a)
- [x] C-2. R13 `prescriptionTimeline`·`transitionCount` + 리포트 처방 전환 세로선·라벨·요약 칸(전환 1회 이상일 때만) + 기록 탭 "처방 변경 · {메모}" 구분 행 (D4-b)
- [x] D. `CycleRules`가 `intervalDays` 대신 7일 고정, `PrescriptionSnapshot`에서 간격 필드 제거 (동작 동일, D4-c)
- [x] E. `Rules/ExportCodec.swift` + 가져오기(교체/추가, 2단계 확인) + `UTExportedTypeDeclarations`(`.masense.json`) — 지금의 JSON 내보내기를 `EXPORT_FORMAT.md` 형식으로. E-1 형식·규칙·서비스·fixture 테스트, E-2 설정 > 데이터 가져오기 시트(S6-1)·내보내기 전 안내. 실기기에서 AirDrop·파일 앱 왕복은 사람 확인
- [x] (사양 대조 중 발견) S6 설정 > 처방 "이전 처방" 접힌 목록 — 시작일~종료일, 메모, 투약 기록·처방 회차 수 (`PrescriptionHistory` + 테스트)

## D5 — 사람 요청 (2026-10-22)

- [x] 앱 버전 0.2
- [x] a. BMI 숫자 (설정 > 신체 정보에서 키 입력, 홈 체중 카드·기록 탭·리포트에 숫자만, 구간 이름 없음, R14). `UserSettings.heightCm` 추가로 SchemaV2 경량 이전 (`SchemaTests`), 내보내기 `settings.heightCm`, 금지선 점검에 구간 이름 추가
- [x] b. 투약 기록 화면 위 "지난 투약" 한 줄(사실만) + 바디맵 구역별 마지막 사용일·부위별 표 (R6 `lastUseBySite`·`lastDoseNote`, 이전 처방 기록 포함)
- [x] c. 시작 전환 화면 1초 (`SplashView`, M 마크 `SplashMark`, 시스템 시작 화면 바탕 midnight)
- [x] d. 앱 아이콘 확정안 "네이비 유리 M" — 다크 네이비 바탕, 1차안 M 그대로(굵기 비율 136) 1.28배, 유리 테두리 약간·조금 더 맑게·굴절 조금 (옵션 R1~R3 중 사람이 R2 선택). 하이라이트 그림 요소 없음. 중간에 굵기 155 `glass`·끝 반사 `clear`안을 거침 (`make_app_icon.py navy`, `SplashMark`도 같이)

## D6 — 쓸모·후킹 (2026-10-23 사람 결정)

게임식 장치(연속 기록·배지·랭킹·축하)는 COMPLIANCE 2.1-4로 쓰지 않는다. "필요한 순간에 한 번에 끝나게"와 "기록이 진료에 바로 쓰이게"로 붙잡는다.

- [x] a1. 알림에서 바로 기록·1시간 뒤 다시 (R4-1, `NotificationActions`, `NotificationResponder`, `AppRouter`)
- [x] a2. 지난 투약 한꺼번에 입력 + 부위 모름 (사람 결정: 부위 모름 허용) — R3-1 `BackfillRules`, `BackfillSheet`(S2-1), 오늘 1-1a 안내 카드, 기록 탭 버튼·부위 고치기(`SiteEditSheet`), `siteRaw "unknown"`
- [x] a3. 진료 때 물어볼 것 메모 — `ClinicQuestion` 모델, SchemaV3(1.2.0) 경량 이전 (사람 결정), R15, 리포트 G 위 섹션, 리포트 탭 카드·오늘 진료 카드·`ClinicQuestionsSheet`(S5-1), 내보내기 `clinicQuestions`
- [x] b1. 홈·잠금화면 위젯 — 위젯 확장 타깃 `MasenseWidgets`(`com.masense.app.widgets`, App Group 같은 ID), `Shared/WidgetSnapshot` JSON, `WidgetRules`·`WidgetService`, SCREENS 위젯. 실기기 확인은 사람 (사람 확인 대기 13번)
- [x] b2. 투약일 Live Activity — `NSSupportsLiveActivities` (사람 결정). 서버가 없어 투약일에 앱을 열었을 때만 시작, 기록하면 끝 (`Shared/DoseDayActivity`, `LiveActivityRules`, `LiveActivityService`, `DoseDayLiveActivity`, SCREENS Live Activity)

## D7 — 사람 요청 (2026-10-23)

약 이름(상표명)은 쓰지 않고 "펜"으로 (COMPLIANCE.md 2.1-2). 용량(mL) 표시는 넣지 않기로 결정.

- [x] a. 오늘 화면 "남은 펜" 카드 — 펜 그림(남은 회차 채움), 남은 펜·회차·소진 예상, 처방 메모 그대로. 설정 > 처방에도 (R13-1 `penStatus`)
- [x] b. 체중 추이 확대 그래프 — 오늘 체중 카드 "추이 보기" → S10, 4주·12주·6개월·전체, 측정값 점 + 주 평균 선, 투약일 눈금, 시작 대비 변화 숫자 (목표선 없음, R7 `trend`)
- [x] c. 주 1회 체중 기록 알림 — 요일·시각 선택(기본 투약 요일 아침 8시), 그날 기록했으면 보내지 않음, 알림에서 체중 입력 시트. `UserSettings` 필드 4개, SchemaV4(1.3.0) 경량 이전 (사람 결정), R4-2, 내보내기 `settings.weightReminder*`

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
| 1 | ~~번들 ID~~ — **결정: `com.masense.app` (2026-10-22)**. 서명 팀도 지정됨 (2026-10-22) | Xcode Signing & Capabilities | 시뮬레이터·CI는 서명 없이 동작 |
| 2 | ~~인앱 구매 상품 ID~~ — **결정: `com.masense.pro` 유지 (2026-10-22)**. App Store Connect에 같은 ID로 비소모성 상품 생성 필요 | `StoreService.productID` | 상품을 못 불러오면 구매 버튼이 안 보임, 복원 버튼만 |
| 3 | ~~HealthKit 사용~~ — **결정: 사용 (2026-10-22), D3-a 반영** | `Config/Masense.entitlements`, `INFOPLIST_KEY_NSHealthShareUsageDescription`, `InfoPlist.xcstrings` | — |
| 4 | ~~처리방침 게시~~ — **결정: https://masense-privacy.vercel.app/ (Vercel), 시행 2026-10-30, 문의 이메일 기재 (2026-10-22)** | `AppConfig.privacyPolicyURL`, `docs/privacy/index.html` | — |
| 5 | ~~단백질 권고 범위 출처~~ — **결정: 표시 (2026-10-22), D3-d 반영.** 2025 공동 권고문(ACLM·ASN·OMA·TOS, Obesity 2025, doi:10.1002/oby.24336; AJCN 판 PMC12264624) "감량 중 1.2~1.6 g/kg/일" | `protein.source`, `protein.guide` | — |
| 6 | ~~감량 속도 출처~~ — **결정: CDC 주 0.5~1 kg 기준으로 표시 (2026-10-22), D3-c 반영** | `pace.notice`, `pace.source`, `PaceRules.weeklyChangeThresholdKg` | — |
| 7 | 맨몸 예시 루틴 문구 검토 | `Localizable.xcstrings`의 `exercise.routine.*` | 초안 그대로 표시 (일반 건강관리 정보 고지와 함께) |
| 8 | ~~리포트 기본 기간 저장~~ — **결정: 저장 (2026-10-22), D3-b 반영** | `UserSettings.reportDefaultPeriod`, SchemaV3 | — |
| 9 | ~~앱 이름~~ — **결정: 마선생 (2026-10-22)**. 아이콘 확정안 "네이비 유리 M"(2026-10-23). 남은 것: 부제 | 스토어 문구(부제), `INFOPLIST_KEY_CFBundleDisplayName`(이미 "마선생"), `scripts/make_app_icon.py` | 부제 없이 이름만 |
| 10 | 실기기 확인: VoiceOver, 최대 글자 크기, 12주 리포트 A4 한 장, 내보내기 → AirDrop·파일 앱 → 가져오기 왕복 | — | — |
| 11 | App Group 실기기 확인: Xcode Signing & Capabilities에서 App Groups `group.com.puertpoyo.masense`가 체크되어 있는지(빨간 표시면 새로고침), 업데이트 설치 후 이전 기록이 그대로 보이는지 | `Config/Masense.entitlements` | 그룹을 못 얻으면 앱 기본 경로를 그대로 써서 기록은 유지 |
| 12 | COMPLIANCE.md 6 출시 전 확인 (상표·명칭·가이드라인) | — | — |
| 13 | 위젯 실기기 확인 (D6): Signing & Capabilities에서 `MasenseWidgets` 타깃의 팀·App Groups `group.com.puertpoyo.masense` 체크, 홈·잠금화면에 위젯을 놓고 투약 기록 뒤 바로 바뀌는지, 예정일에 눌러 투약 기록 시트가 열리는지. 투약일에 앱을 열면 잠금화면·Dynamic Island에 Live Activity가 뜨고 기록하면 사라지는지 | `Config/MasenseWidgets.entitlements` | 그룹을 못 얻으면 위젯은 "처방을 입력하면…"만 보이고 앱은 그대로 |

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
| 2026-10-22 | 앱 아이콘 1차안 "겹친 유리 M"(막대 굵기 136) | 사람 선택. 의약품 상표 연상·주사기·알약 표현 제외 |
| 2026-10-23 | 앱 아이콘 확정안 "네이비 유리 M"(다크 네이비 바탕, 1차안 M × 1.28배, 유리 테두리 약간·조금 더 맑게·굴절 조금, 옵션 R2) | 사람 확정. 하이라이트 그림 요소는 뺌. 굵기 155안은 "볼륨은 1차안 정도"로 되돌림. 막대는 계속 단색(두 색 나눔·이음선 없음) |
| 2026-10-22 | 앱 이름 "마선생" 확정 | 사람 결정. 상표 등록 검색은 COMPLIANCE.md 6 출시 전 확인에 남김 |
| 2026-10-22 | 번들 ID `com.masense.app` (테스트 `com.masense.app.tests`) | 사람 결정. 앱스토어에 올린 뒤에는 바꿀 수 없다 |
| 2026-10-22 | 출시 전 스키마 재정리: V1~V3 이력을 접고 CloudKit 호환 규칙 + 처방 endDate를 담은 새 SchemaV1 | 사람 결정. 사용자 데이터 없음, 영구히 남을 옛 필드를 만들지 않으려고 |
| 2026-10-22 | 앱 버전(`MARKETING_VERSION`) 0.2 | 사람 결정. 빌드 번호(`CURRENT_PROJECT_VERSION`)는 1부터, TestFlight 업로드마다 올린다 |
| 2026-10-22 | BMI는 숫자만 (구간 이름 없음), 키 입력은 설정에서 선택, SchemaV2 경량 이전 | 사람 결정. 판단어 금지(3.1)와 목표 체중 금지(2.1-3)를 지키면서 진료 때 참고할 숫자만 |
| 2026-10-22 | 투약 시 안내는 지난 부위·날짜 사실만, 바디맵에 부위별 마지막 날짜 | 사람 결정. R6 부위 추천 금지 유지 |
| 2026-10-22 | 시작 전환 화면 1초 | 사람 요청. 담담한 페이드만 |
| 2026-10-21 | `Prescription.scheduledTime`은 `scheduledHour`·`scheduledMinute` Int 2개로 저장, `DateComponents`는 계산 속성 | SwiftData Codable 저장 안정성 |
| 2026-10-21 | Xcode 16 폴더 동기화 그룹 + GitHub Actions macOS CI | Xcode 없는 환경(Claude Code 클라우드)에서도 파일 추가·검증 가능 |
| 2026-10-21 | 단위 테스트는 Swift Testing | iOS 17+/Xcode 16 기준, 선언적 `#expect` |
| 2026-10-21 | SwiftData 스토어를 App Group 컨테이너에 배치 | v2 위젯·Live Activity·Watch가 같은 스토어 공유, 이전 비용 회피 |
| 2026-10-21 | 스키마는 v1부터 CloudKit 호환 규칙 적용 (unique 금지, 기본값/옵셔널, 관계 옵셔널), 동기화는 꺼 둠 | 기기 교체·분실 대비, 나중에 스위치만 켜면 되게 |
| 2026-10-21 | 처방을 삭제하지 않고 startDate/endDate 체인으로 보관, 리포트 타임라인에 처방 전환 세로선 + doseLabel 표시 | 의사가 "언제 단계가 바뀌었나"를 바로 읽게. 라벨은 표시만, 해석 안 함 |
| 2026-10-21 | v1은 주 1회(7일) 전용. intervalDays 필드는 7 고정으로만 보유 | 매일·격주 주기는 컨디션 창·알림 64개 제한과 충돌, v2에서 R1·R4·R5 재설계 |
| 2026-10-21 | 내보내기·가져오기 JSON 스키마 확정 (formatVersion 1, 평탄화·ID 참조, HealthKit 샘플은 가져오기 제외) | 동기화 켜기 전 기기 교체 수단, 사용자 데이터 소유권 |
