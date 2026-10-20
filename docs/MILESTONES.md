# MILESTONES — 빌드 순서

Claude Code는 매 세션 이 파일에서 현재 위치를 확인하고, 완료한 항목의 체크박스를 갱신합니다. 한 마일스톤 안에서는 위에서 아래 순서로 진행합니다.

## M0 — 뼈대 (0.5주)

완료 기준: 빈 앱이 빌드·실행되고, 테스트 타깃이 돌고, 디자인 토큰이 보인다.

- [ ] Xcode 프로젝트 `Masense` 생성 (iOS 17, SwiftUI, SwiftData 체크 해제 후 수동 구성)
- [ ] `CLAUDE.md` 폴더 구조대로 그룹 생성
- [ ] `DesignSystem/` 토큰 (`Color+Tokens`, `Spacing`, `Typography`), `FrostCard`, `PrimaryButton`, `RecordedToast`
- [ ] App Groups capability 추가 (`group.com.puertpoyo.masense`)
- [ ] `App/ModelContainer+Masense.swift` — App Group 경로에 `ModelContainer` 구성 (SchemaV1), 미리보기·테스트용 in-memory 팩토리
- [ ] `App/MasenseApp.swift` — 다크 고정, 컨테이너 주입
- [ ] `Localizable.xcstrings` 생성, `COMPLIANCE.md` 3.2 고정 문구 등록
- [ ] `MasenseTests` 타깃, 더미 테스트 1개 통과
- [ ] 탭 3개 빈 화면 + 설정 push

## M1 — 투약 루프 MVP (2~3주)

완료 기준: 온보딩 → 투약 기록 → 컨디션 체크 → 리포트 PDF까지 한 바퀴가 돈다. TestFlight 1차.

### M1-a 모델·규칙
- [ ] `Models/` SchemaV1 5개 모델 (`DATA_MODEL.md`)
- [ ] `Rules/CycleRules.swift` R1·R2·R3 + 테스트
- [ ] `Rules/NotificationRules.swift` R4 + 테스트
- [ ] `Rules/ConditionRules.swift` R5 + 테스트
- [ ] `Rules/SiteRules.swift` R6 + 테스트
- [ ] `Rules/WeightRules.swift` R7 + 테스트
- [ ] `Rules/PrescriptionRules.swift` R13 + 테스트

### M1-b 서비스
- [ ] `NotificationService` — 권한, 4주 재등록, Dose 기록 시 취소
- [ ] `HealthKitService` — 권한, `bodyMass` 읽기, 캐시 upsert (프로토콜 + Fake)
- [ ] `StoreService` — StoreKit 2 비소모성 1종, 복원 (프로토콜 + Fake)

### M1-c 화면
- [ ] S0 온보딩 4페이지
- [ ] S9 PrescriptionSheet
- [ ] S1 TodayView: 1-1 카운트다운, 1-2 컨디션, 1-3 체중, 1-5 진료
- [ ] S2 DoseLogSheet + `BodyMapView`
- [ ] S3 ConditionCheckSheet
- [ ] S4 HistoryView 투약·컨디션·체중
- [ ] S6 SettingsView 처방·알림·연동·구매·데이터·정보
- [ ] WeightEntrySheet

### M1-d 리포트
- [ ] `Rules/ReportBuilder.swift` — `ClinicReport` 생성, 섹션 A~E·G·H + 스냅샷 테스트
- [ ] `ReportView` 미리보기 (SwiftUI, 라이트 강제)
- [ ] `ReportRenderer` — `ImageRenderer` → PDF, `ShareLink`
- [ ] 구매 게이트

### M1-e 마감
- [ ] 접근성 점검 (VoiceOver, Dynamic Type XXL)
- [ ] `COMPLIANCE.md` 2.1 금지선 전수 확인 (문구 grep: 약물명, "용량", "목표 체중", 느낌표)
- [ ] 개인정보 처리방침 페이지
- [ ] TestFlight 빌드, 베타 안내문 (역할·연령 고지 포함)

## M2 — 근육 지키는 감량 (2주)

완료 기준: 단백질·운동 기록이 홈과 리포트에 반영된다. TestFlight 2차.

### M2-a 모델·규칙
- [ ] SchemaV2 + `SchemaMigrationPlan` (V1 → V2 경량)
- [ ] `ProteinEntry`, `StrengthSession`, `HabitCheck`
- [ ] `Rules/ProteinRules.swift` R9·R10 + 테스트
- [ ] `Rules/StrengthRules.swift` R11 + 테스트
- [ ] `Rules/PaceRules.swift` R8 + 테스트
- [ ] `isLowConditionDay` 공용 함수

### M2-b 화면
- [ ] S1 1-4 오늘의 마디 카드
- [ ] S7 ProteinSheet (식욕 저하일 모드 포함)
- [ ] S8 StrengthSheet (저컨디션 순서, 예시 루틴 접힘)
- [ ] S4 습관 세그먼트 캘린더
- [ ] S6 단백질 설정 섹션
- [ ] 1-3 체중 카드에 `paceNotice`

### M2-c 리포트·연동
- [ ] `ReportBuilder` F 섹션
- [ ] `HealthKitService` `leanBodyMass` 읽기
- [ ] (P2) HealthKit workout → StrengthSession 자동 인식
- [ ] 리포트 테마 3종 (`accent` 교체)

### M2-d 마감
- [ ] 금지선 재확인 (판단어 grep: 좋음, 부족, 충분, 성공, 달성)
- [ ] TestFlight 2차

## M3 — 출시 준비 (1주)

- [ ] `COMPLIANCE.md` 6 출시 전 확인 전부
- [ ] 스토어 스크린샷 (약물명·용량 없음)
- [ ] 스토어 설명 (COMPLIANCE 4.5 방향)
- [ ] 연령 등급 설문
- [ ] 심사 제출

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
| 2026-10-21 | SwiftData 스토어를 App Group 컨테이너에 배치 | v2 위젯·Live Activity·Watch가 같은 스토어 공유, 이전 비용 회피 |
