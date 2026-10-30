# RULES — 비즈니스 규칙

`Masense/Rules/`의 순수 함수 사양입니다. 모든 함수는 `Calendar`와 `now: Date`를 인자로 받고, SwiftUI·SwiftData를 import하지 않으며, 각 규칙에 단위 테스트가 있어야 합니다.

## 전제: 주 1회 전용

v1의 모든 규칙은 **7일 간격 주 1회 투약**을 전제로 한다. `Prescription.intervalDays`는 항상 7이며 Rules는 이 값을 읽지 않는다. 다른 주기(매일, 격주)는 v2 이후 별도 결정 — 그때 R1·R4·R5가 함께 바뀐다.

## R1. 마디(Cycle) 계산

```swift
struct Cycle { let index: Int; let scheduledDate: Date; let interval: DateInterval }
func cycles(for p: PrescriptionSnapshot, doses: [DoseSnapshot], now: Date, until end: Date, calendar: Calendar) -> [Cycle]
```

- 첫 마디 `scheduledDate` = `startDate` 당일 또는 그 이후 첫 `scheduledWeekday` + `scheduledHour`:`scheduledMinute`. 시작일이 예정 요일과 같은 날이면 그날이 첫 마디
- 이후 마디 = 첫 마디 + 7일 × index (누적 오차 없음). 주 1회 전용이라 `intervalDays`를 읽지 않는다 (`CycleRules.intervalDays = 7`, `PrescriptionSnapshot`에도 간격 필드가 없다)
- 마디 구간 `interval` = `[scheduledDate - 2일, scheduledDate + 5일)` — 예정일 이틀 전부터 그 마디로 본다 (미리 맞는 경우 수용)
- 처방이 소진되면 그 이후 마디는 만들지 않음. 소진은 "쓰인 회차"로 센다: 기록이 있는 마디와 현재·미래 마디는 회차를 쓰고, 지나간 누락 마디는 쓰지 않는다. 그래서 누락이 있으면 마디가 그만큼 뒤로 늘어나 `remainingDoses`와 맞는다
- `until`은 `scheduledDate` 상한. 전체를 원하면 `.distantFuture` (회차 수로 끝난다)

테스트: 목요일 20:00, 7일 간격, 시작일이 금요일인 경우 첫 마디는 다음 목요일.

## R2. 다음 투약과 카운트다운

```swift
func nextDose(cycles: [Cycle], doses: [DoseSnapshot], now: Date) -> NextDose?
enum NextDose { case due(Cycle, remaining: TimeInterval), overdue(Cycle, elapsed: TimeInterval), done(Cycle, next: Cycle?) }
```

- 현재 마디에 Dose가 없고 `now < scheduledDate` → `.due`
- 현재 마디에 Dose가 없고 `now >= scheduledDate` → `.overdue`. UI 문구는 "예정일이 지났습니다" (질책 없음)
- 현재 마디에 Dose가 있음 → `.done`, 다음 마디 안내
- 처방 소진 후 → `nil`, 홈은 "새 처방을 입력하세요"

## R3. 누락(Missed) 판정

- 마디 구간이 끝났는데 (now ≥ interval.end) 그 구간에 취소되지 않은 Dose가 없으면 누락
- 누락은 저장하지 않고 항상 계산. 리포트에는 "누락 n회"로 표시만 함
- 누락 뒤 사용자가 "맞았는데 기록을 안 했다"면 과거 날짜로 Dose 추가 가능 → 누락 해제

### R3-1. 지난 투약 한꺼번에 입력 (D6, 2026-10-23 사람 결정)

이 앱을 쓰기 전에 치료를 시작한 사람이 지난 투약을 한 번에 채우는 기능. 앱은 어느 주를 맞았는지 판단하지 않고, 사용자가 켜 둔 주만 기록한다.

```swift
func candidates(prescription: PrescriptionSnapshot, doses: [DoseSnapshot], now: Date, calendar: Calendar) -> [Cycle]  // 활성 처방의 누락 마디 (R3)
func leadingCount(candidates: [Cycle], doses: [DoseSnapshot]) -> Int      // 첫 기록(취소 제외)보다 앞선 누락 수, 기록 없으면 전부
func defaultSelection(candidates: [Cycle], remaining: Int) -> Set<Int>    // 처음에 켜 둘 마디 index: 최근부터 남은 회차까지
func plan(selected: [Date], doses: [DoseSnapshot]) -> Plan                // 새 기록 회차, 밀리는 기존 기록 회차
```

- 대상은 **활성 처방**의 누락 마디만. 보관된 처방의 누락은 기록 탭에서 보기만 한다 (기존과 같음)
- 기록 시각 = 마디 예정 일시 (`administeredAt == scheduledFor`)
- 켤 수 있는 수는 남은 회차(R13 `remainingDoses`)까지. 처음에는 최근 마디부터 남은 회차만큼 켠다
- 부위는 고르거나 비워 둔다. 비우면 `siteRaw = "unknown"` (부위 기록 없음, R6)
- 회차: 새 기록은 취소되지 않은 기존 기록과 합쳐 시간 순으로 센 번호. 새 기록보다 뒤에 맞은 기존 기록은 그 앞에 넣은 새 기록 수만큼 회차가 밀린다. 취소된 기록은 세지도 바꾸지도 않는다
- 오늘 화면 안내 카드는 `leadingCount > 0`이고 남은 회차가 있을 때만 (첫 기록 뒤의 누락은 "앱을 쓰기 전"이 아니므로 세지 않는다). 기록 탭 버튼은 누락이 2개 이상일 때 (1개는 누락 행을 눌러 기록)
- 컨디션: 창(투약 후 96시간)이 다 닫힌 뒤에 만든 기록은 체크가 하나도 없으면 기록 탭 컨디션 목록에 빈칸을 만들지 않는다 (`createdAt` 기준). 체크가 있으면 그대로 보인다

## R4. 알림 스케줄

```swift
func notificationPlan(p: PrescriptionSnapshot, settings: SettingsSnapshot, doses: [DoseSnapshot], checks: [ConditionCheckSnapshot], now: Date, calendar: Calendar) -> [PlannedNotification]
struct PlannedNotification { let id: String; let kind: NotificationKind; let fireDate: Date; let argument: Int? }
```

- `id`는 결정적(`dose.due.<마디>`, `condition.h24.<기록 id>`, `clinic.soon` …)이라 재등록해도 중복이 없다
- `reminderEnabled`가 꺼지면 투약·저녁·소진 알림을 만들지 않고, `conditionCheckEnabled`가 꺼지면 컨디션 알림을 만들지 않는다. 진료 알림은 `nextClinicDate`만 있으면 만든다
- 이미 지난 시각(`fireDate <= now`)은 만들지 않는다

| 종류 | 시점 | 조건 | 문구 키 |
|---|---|---|---|
| 투약 | 마디 `scheduledDate` | 그 마디에 Dose 없음 | `notif.dose.due` "오늘은 투약일입니다" |
| 저녁 리마인드 | 같은 날 `eveningReminderHour`:00 | 여전히 Dose 없음, `scheduledHour` < eveningReminderHour | `notif.dose.evening` "아직 기록이 없습니다" |
| 컨디션 24h | Dose.administeredAt + 24h | `conditionCheckEnabled`, 해당 window 체크 없음 | `notif.condition.h24` "투약 후 하루, 컨디션을 기록해 주세요" |
| 컨디션 48h | + 48h | 동일 | `notif.condition.h48` |
| 진료 | `nextClinicDate - clinicReminderDaysBefore` 09:00 | nextClinicDate 있음 | `notif.clinic.soon` "내일 진료입니다. 리포트를 준비해 두세요" |
| 소진 | 다음 투약 알림과 함께 | `remainingDoses <= exhaustionReminderDosesLeft` | `notif.prescription.low` "남은 회차가 n회입니다. 진료 예약을 확인하세요" |
| 체중 (D7, R4-2) | 주 1회 정한 요일·시각 | `weightReminderEnabled`, 그날 체중 기록 없음 | `notif.weight.due` "오늘 체중을 기록할 수 있습니다." |

- 로컬 알림은 iOS 제한(64개) 때문에 **앞으로 4주치**만 등록하고, 앱이 포그라운드로 올 때마다 전부 취소 후 재등록
- Dose를 기록하면 그 마디의 투약·저녁 알림을 즉시 제거
- 알림 문구에 약 이름·용량 없음

### R4-1. 알림에서 바로 하는 일 (D6, 2026-10-23 사람 결정)

```swift
enum NotificationActions { static func category(for: NotificationKind) -> String?; static func response(action:category:) -> Response?; static func snoozed(kind:now:) -> PlannedNotification }
enum AppRoute { case logDose, conditionCheck, logWeight }
```

| 알림 | 버튼 (알림을 길게 누름) | 본문을 누름 |
|---|---|---|
| 투약·저녁 리마인드 | "기록하기"(앱을 열고 투약 기록 시트) · "1시간 뒤 다시 알림"(앱을 열지 않음) | 투약 기록 시트 |
| 컨디션 24h·48h | "컨디션 기록"(지금 열린 컨디션 체크 시트) | 컨디션 체크 시트 |
| 체중 (D7) | "체중 기록"(체중 입력 시트) | 체중 입력 시트 |
| 진료·소진 | 없음 | 앱만 연다 |

- 미루기는 같은 문구를 **한 시간 뒤 한 번** 더 보낸다(`dose.snooze`, 다시 미루면 덮어씀). 앱이 판단하지 않는다
- 미룬 알림은 포그라운드 재등록(R4)에도 남고, 투약을 기록하면 지운다
- 처방이 없거나 열린 컨디션 체크가 없으면 오늘 화면만 연다

### R4-2. 체중 기록 알림 (D7, 2026-10-23 사람 결정)

```swift
func weightReminders(settings: SettingsSnapshot, prescriptionWeekday: Int?, weights: [WeightSampleSnapshot], now: Date, calendar: Calendar) -> [PlannedNotification]
```

- 주 1회. 요일은 설정값, 없으면 처방의 투약 요일, 처방도 없으면 월요일. 시각 기본 08:00. 기본 켜짐
- 앞으로 4주치(R4와 같은 범위), id `weight.due.<yyyyMMdd>`. 지난 시각은 만들지 않는다
- 그날 이미 체중을 기록했으면(직접 입력·건강 앱 모두) 그날 알림은 만들지 않는다. 체중을 저장하면 알림을 다시 계산한다
- 처방이 없어도 보낸다 (체중은 처방과 따로 기록). 문구는 사실만, 목표·변화량 언급 없음

## R5. 컨디션 체크 윈도우

```swift
func openConditionWindows(dose: DoseSnapshot, checks: [ConditionCheckSnapshot], now: Date) -> [ConditionWindow]
```

- `.h24`: `administeredAt + 12h ≤ now < administeredAt + 36h`, 아직 h24 체크 없음
- `.h48`: `administeredAt + 36h ≤ now < administeredAt + 96h`, 아직 h48 체크 없음
- 창이 닫히면 홈에서 사라지고, 기록 화면에서는 "지난 체크"로 추가 입력 가능 (리포트에는 포함)

## R6. 바디맵 표시

```swift
struct SiteUse { let site: BodySite; let date: Date }
func siteHistory(doses: [DoseSnapshot], limit: Int = 4) -> [SiteUse]
func recencyRank(of site: BodySite, in history: [SiteUse]) -> Int?   // 0이 가장 최근, 없으면 nil
```

- 최근 4회 사용 부위와 날짜를 돌려줌. UI는 최근 순으로 진하게 표시 (`Color.siteRecent(rank:)`)
- 표시 (DESIGN_SYSTEM.md 5.3): 직전 1회는 `accent` 채움 + "① 마지막: 부위 (M/d)" 칩, 2~4회는 옅은 채움·얇은 테두리 + "② 이전: 부위 (M/d)" 텍스트
- **추천하지 않는다.** "다음은 왼쪽 허벅지" 같은 제안 없음. 사용자가 보고 고름
- D5 (2026-10-22 사람 결정):

```swift
func lastUseBySite(doses: [DoseSnapshot]) -> [BodySite: Date]            // 부위별 마지막 사용, 취소 제외, 쓴 적 없으면 키 없음
func lastDoseNote(doses: [DoseSnapshot], now: Date, calendar: Calendar) -> LastDoseNote?   // 직전 투약 부위·시각, 달력 기준 지난 날 수
```

  - 바디맵 구역 날짜와 "부위별 마지막 사용" 표, 투약 기록 화면 위 "지난 투약" 한 줄에 쓴다. 문구는 사실만 ("지난 투약 / 허벅지 왼쪽 / 10월 15일 (목) · 7일 전")
  - 입력은 처방과 무관하게 모든 투약 기록 (새 처방을 시작해도 이전 처방의 부위가 보이게)
- 부위 기록 없음 (D6): `DoseSnapshot.site == nil` (`siteRaw = "unknown"`이나 모르는 값). `siteHistory`·`lastUseBySite`에서 빠진다 (바디맵 이력에 나오지 않음). `lastDoseNote`는 직전 투약이 부위 기록 없음이면 부위 없이 알린다. 기록 탭·리포트에는 "부위 기록 없음"/"—"으로 보이고, 기록 탭에서 눌러 나중에 부위를 고칠 수 있다

## R7. 체중 추이

```swift
func weeklyWeightSeries(samples: [WeightSample], weeks: Int, now: Date, calendar: Calendar) -> [WeekPoint]
struct WeekPoint { let weekStart: Date; let averageKg: Double?; let sampleCount: Int }
```

- 주 단위 평균. 샘플 없는 주는 `nil`로 두고 선을 끊음 (보간 금지)
- 같은 날 여러 샘플이면 먼저 하루 평균으로 묶고, 그 하루 평균들의 평균을 주 평균으로 한다
- 결과는 오래된 주부터 `weeks`개, 마지막이 `now`가 속한 주. 주 시작은 `calendar.firstWeekday`
- 차트의 투약일 눈금은 `doseTicks(doses:series:now:)`: 시리즈 첫 주 시작부터 `now`까지, 취소한 기록 제외 (홈 스파크라인, 기록 탭 차트)
- D7 확대 그래프 `trend(samples:range:now:calendar:) -> WeightTrend`: 기간 4주·12주·26주(6개월)·전체(첫 기록이 있는 주부터, 최소 4주). 주 평균(위와 같음)과 하루 평균 점. `changeText` = 기간 마지막 측정일 - 첫 측정일, 소수 1자리 부호 그대로("-3.2", "+0.4"), 측정일 2일 미만이면 없음. 목표선·판단 색·속도 평가 없음

## R8. 감량 속도 안내 (M2)

```swift
func paceNotice(series: [WeekPoint]) -> PaceNotice?
enum PaceNotice { case fasterThanGeneralGuide }
```

- 최근 2주 연속으로 주당 감소가 **1.0 kg** 를 넘으면 `.fasterThanGeneralGuide`
  - 구현: 주 평균 시리즈의 마지막 3주로 주간 변화(kg) 2개를 만들고 둘 다 -1.0 kg 미만이면 해당. 3주 중 빈 주가 있으면 계산하지 않음
  - 기준: 일반 권장 속도 주 0.5~1 kg의 상한. 출처 CDC(주 1~2파운드). 2026-10-22 사람 결정으로 주 1% 기준에서 바꿈
- 문구: "최근 2주 체중이 일반 권장 속도(주 0.5~1 kg)보다 빠르게 줄었습니다. 일반적인 권장일 뿐 사람마다 다를 수 있으니 의사와 상의하세요." + 출처 한 줄(`pace.source`)
- 느린 경우, 증가하는 경우에는 **아무 안내도 하지 않는다**
- 샘플이 주 1회 미만이면 계산하지 않음

## R9. 단백질 목표 안내 (M2)

```swift
func proteinGuideRange(weightKg: Double) -> ClosedRange<Int>   // 1.2~1.6 g/kg, 정수 g
func proteinDayStatus(entries: [ProteinEntry], target: Int?) -> ProteinDayStatus
enum ProteinDayStatus { case noTarget(estimated: Int), below(estimated: Int, target: Int), met(estimated: Int, target: Int) }
```

- 목표가 없으면 상태는 `.noTarget`, UI는 추정치만 보여 주고 "의사·영양사와 정한 목표를 입력할 수 있습니다"
- 목표 달성은 "채웠습니다" 한 줄. 미달은 "n g 기록" 만. 경고·색 변화 없음
- 안내 범위 옆에 항상 "신장 질환 등 개인 상황은 의사와 상의하세요" 고정 문구

### 식품별 기본 단백질 g (1회 기준, 사용자가 수정 가능)

| 식품 | g | 식품 | g |
|---|---|---|---|
| 계란 1개 | 6 | 생선 1토막(100g) | 20 |
| 두부 1/2모(150g) | 12 | 소고기(100g) | 22 |
| 닭가슴살(100g) | 23 | 돼지고기(100g) | 20 |
| 그릭요거트(150g) | 15 | 콩·두유(1컵) | 8 |
| 단백질 셰이크(1회) | 20 | 우유(1컵) | 7 |
| 치즈(1장) | 5 | 기타 | 사용자 입력 |

수치는 일반 식품 평균 추정치이며 앱은 "대략"으로 표기. 출처는 설정 화면에 명시.

## R10. 식욕 저하일 모드 (M2)

- 최근 48h 내 ConditionCheck에서 `nausea ≥ 2` 또는 `appetite != .normal`이면 그 날 단백질 화면 상단에 "작게 자주" 섹션: 셰이크, 요거트, 두유, 계란
  - `ConditionRules.isLowAppetiteDay(checks:now:)`. R11의 `isLowConditionDay`와 조건이 다르다 (DESIGN_SYSTEM.md 5.6, 2026-10-21 분리)
- 끼니를 비워도 "건너뜀"이라는 단어·아이콘을 쓰지 않는다. 비어 있을 뿐

## R11. 근력운동 마디 (M2)

```swift
func strengthWeekSummary(sessions: [StrengthSession], weekOf: Date, calendar: Calendar) -> StrengthWeek
struct StrengthWeek { let strengthCount: Int; let lightCount: Int; let restCount: Int }
```

- 주간 목표 수치를 화면에 띄우지 않는다. "이번 주 근력 2회" 같은 사실만
- `isLowConditionDay(checks:now:)`: 최근 48h 체크에 강도 2 이상 증상이 있으면 (식욕은 보지 않음)
- `kindOrder(isLowCondition:)`: 평소 근력 / 걷기 / 스트레칭 / 쉬기, 저컨디션 날 걷기 / 스트레칭 / 쉬기 / 근력
- 가벼운 활동 = 걷기 + 유산소(D16) + 스트레칭, 화면 이름 "걷기·유산소 등". 운동 기록 순서는 근력·걷기·유산소·스트레칭·쉬기 (저컨디션 날 걷기·스트레칭·쉬기·근력·유산소). 주는 `calendar.firstWeekday` 기준
- 최근 48h 컨디션에 심각도 2 이상 증상이 있으면 운동 기록 화면에서 걷기·스트레칭·쉬기를 상단에 배치 (R10과 같은 조건 함수 공유: `isLowConditionDay`)

## R12. 리포트 기간

- 기본: `nextClinicDate`가 있으면 직전 진료일(이전 처방 startDate) ~ 오늘, 없으면 최근 8주
  - 구현 해석: "직전 진료일" = 현재(활성) 처방의 `startDate` (진료 후 새 처방을 입력하므로). 활성 처방이 없거나 시작일이 미래면 최근 8주
  - "최근 n주" = 오늘을 포함한 7×n일. 주 수 표기는 기간 일수를 7로 나눠 올림
- 마디 칸은 기간 안 예정일 기준, 최대 12칸(최근 12개). 보관된 처방은 다음 처방 시작 전까지의 마디만 (`CycleRules.pastCycles`)
- 컨디션 응답률 분모 = 기간 안 투약 중 창이 열린(투약 후 12h·36h 경과) 개수
- 사용자가 4·8·12주 중 선택 가능
- 설정에 기본 기간을 저장할 수 있다 (2026-10-22 결정, `UserSettings.reportDefaultPeriod`). 리포트 탭을 열 때 `defaultPeriod(saved:hasActivePrescription:hasNextClinicDate:)`: 저장 값이 고를 수 있는 값이면 그것, 아니면(저장 안 함 = 자동, 활성 처방 없이 "직전 진료 이후", 선택지에 없는 주 수) 위 기본값
- 리포트 생성 시각과 기간을 PDF 하단에 명시

## R13. 처방 소진 추정과 처방 전환

```swift
func exhaustionEstimate(p: PrescriptionSnapshot, doses: [DoseSnapshot], now: Date, calendar: Calendar) -> Date?
func nextSequence(doses: [DoseSnapshot]) -> Int                        // 취소 제외 기록 수 + 1
func penPosition(sequence: Int, dosesPerPen: Int) -> (pen: Int, position: Int)
func prescriptionTimeline(all: [PrescriptionSnapshot], in period: DateInterval, calendar: Calendar) -> [PrescriptionMarker]
func transitionCount(_ markers: [PrescriptionMarker]) -> Int          // 마커 수 - 1
struct PrescriptionMarker { let startDate: Date; let label: String?; let isFirstInPeriod: Bool }
```

- 새 처방 시작(`startNewPrescription`)은 Rules가 아니라 서비스 계층에서: 이전 활성 처방의 `endDate = 새 startDate - 1일`, `isActive = false`, 새 처방 `isActive = true`. 트랜잭션 하나로
- `prescriptionTimeline`은 기간과 겹치는 처방을 `startDate` 오름차순으로 돌려주고, 기간 시작 전에 이미 시작된 처방은 `isFirstInPeriod = true`로 표시 (리포트에서 "기간 시작 시점의 처방"으로 쓰임)
- `label`은 사용자 메모 그대로(앞뒤 공백 제거). 비어 있으면 nil이고 UI는 "처방 변경"으로만 표시
- `endDate`는 그날 하루 끝까지 유효로 본다. 기간 전에 끝난 처방, 기간 뒤에 시작하는 처방은 빠진다
- 소진 추정:
  - `remainingDoses == 0` → nil
  - 그 외 남은 회차를 모두 쓰는 마지막 마디의 `scheduledDate` (= R1 `cycles(until: .distantFuture)`의 마지막 마디). 누락이 있으면 그만큼 뒤로 밀린다

### R13-1. 펜 현황 (D7, 2026-10-23 사람 결정)

```swift
func penStatus(p: PrescriptionSnapshot, doses: [DoseSnapshot]) -> PenStatus
struct PenStatus { let usedPerPen: [Int]; let dosesPerPen: Int }   // remainingPens, remainingDoses
```

- 펜 수 = `totalDoses / dosesPerPen`. 쓴 회차(취소 제외, 처방 회차를 넘지 않게)를 앞 펜부터 차례로 채운다
- "남은 펜"은 한 회차라도 남은 펜 수(쓰는 중인 펜 포함)
- 1회용 펜 (2026-10-24 사람 설명: 펜 하나에 한 번, 패키지 하나에 펜 4개 = 한 달치): 펜당 회차 1. `PenStatus.packages`가 펜을 4개씩 패키지로 묶는다(`dosesPerPackage = 4`). 여러 회 쓰는 펜은 펜 하나가 묶음 하나
- R13-2 처방 구간 색 (D7, 2026-10-24 사람 결정): `colorSlots(startDates:) -> [Int]` 처방 시작 순서(같으면 입력 순서)대로 0, 1, 2, 3, 0 … (`colorSlotCount = 4`). 처방을 구분할 뿐 용량·단계와 무관하고 순서·강도 의미가 없다. 남은 펜 그림·처방 메모 점, 기록 탭 투약 행 왼쪽 띠·처방 변경 행 점, 설정 이전 처방 점, 리포트 C 칸 위 띠·라벨 점(기간 안에 처방 전환이 있을 때만)
- `packagePosition(sequence:)`: 1회용 펜의 n회차 = 패키지 ⌈n/4⌉의 ((n-1) mod 4)+1번째 펜 (투약 기록 화면 회차 표시)
- 용량(mg·mL) 수치는 다루지 않는다 (2026-10-23 사람 결정: 넣지 않음). 처방 메모는 사용자가 적은 그대로만 함께 보인다

## R14. BMI 숫자 (D5)

```swift
static let bmiHeightRangeCm: ClosedRange<Double> = 100...250
func bmi(kilograms: Double, heightCm: Double?) -> Double?   // kg / m², 소수 1자리 반올림
```

- 2026-10-22 사람 결정: **숫자만** 보여 준다. 저체중·정상·과체중·비만 같은 구간 이름, 색, 화살표로 판단하지 않는다 (COMPLIANCE.md 2.2, 3.1)
- 키는 설정 > 신체 정보에서 사용자가 입력(선택). 없거나 100~250 cm 밖이면 nil이고 화면은 BMI를 숨긴다. 체중이 0 이하면 nil
- 표시: 홈 체중 카드(최근 체중의 BMI), 기록 탭 체중 목록(샘플마다), 리포트 B 체중 칸 보조 줄("BMI 28.5 → 27.4", 기간 첫·마지막 체중)
- BMI 목표 입력·목표 BMI까지 남은 값 같은 표현은 만들지 않는다 (2.1-3 목표 체중과 같은 이유)

## R15. 진료 때 물어볼 것 (D6, 2026-10-23 사람 결정)

```swift
static let maxLength = 200
func normalized(_ text: String) -> String?                                  // 앞뒤 공백 제거, 줄바꿈 → 공백, 비면 nil, 200자에서 자름
func pending(_ questions: [ClinicQuestionSnapshot]) -> [ClinicQuestionSnapshot]  // 아직 묻지 않은 것, 적은 순
func asked(_ questions: [ClinicQuestionSnapshot]) -> [ClinicQuestionSnapshot]    // 물어본 것, 최근에 물어본 순
```

- 사용자가 적은 문장을 그대로 둔다. 앱은 질문을 분류하거나 답하거나 "이런 걸 물어보세요" 같은 제안을 하지 않는다 (의료 조언 아님)
- 리포트 (`ReportBuilder.questionLines`): 아직 묻지 않은 것 중 리포트를 만든 시각까지 적은 것을 적은 순으로 최대 5개, 60자에서 자름. 기간과 무관 (다음 진료를 위한 것)
- 리포트 G 영역은 물어볼 것과 메모를 합쳐 8줄까지: 메모는 `min(5, 8 - 물어볼 것 수)`줄. A4 한 장 유지 (`ReportRendererTests.fullTwelveWeekReportFitsOnePage`)
- 진료에서 물어봤으면 눌러서 `askedAt`을 남긴다. 다시 누르면 되돌린다. 지우기는 실제 삭제

## R16. 주간 정리 (D8, 2026-10-24 사람 결정)

```swift
func finishedPeriods(prescription: PrescriptionSnapshot, now: Date, calendar: Calendar, limit: Int = 12) -> [DateInterval]  // 끝난 구간, 최근 순
func summary(period:doses:checks:weights:proteins:sessions:proteinTarget:calendar:) -> WeeklySummary
```

- 구간은 활성 처방의 첫 예정일(R1)이 있는 날 0시부터 7일씩 `[시작, +7일)`. 끝난 구간만
- 숫자만: 투약 수(취소 제외), 컨디션 체크 수와 강도 1 이상으로 많이 기록된 증상 최대 2개, 체중 측정 수와 구간 첫·마지막 측정 차이(부호 그대로, 2회 이상일 때), 단백질 기록한 날(목표가 있으면 채운 날, R9), 근력운동·가벼운 활동 수
- 평가어·지난 구간과의 비교·목표 대비 문구 없음. 기록이 하나도 없는 구간은 오늘 카드로 띄우지 않는다

## R17. 오늘 화면 사실 한 줄 (D8, 2026-10-24 사람 결정)

```swift
func line(prescription: PrescriptionSnapshot?, doses: [DoseSnapshot], allDoses: [DoseSnapshot], weights: [WeightSampleSnapshot], now: Date, calendar: Calendar) -> DailyLine?
```

- 하나만, 우선순위: 오늘이 예정일이고 기록 전("오늘은 투약일입니다. 지난 부위: …") > 남은 회차 1회 이하("남은 펜이 n개입니다. 다음 진료일을 확인하세요.", 여러 회 쓰는 펜은 회차) > 최근 7일 체중 기록 없음
- 칭찬·응원·평가 없음 (COMPLIANCE.md 3.1). 닫으면 같은 종류는 그날 다시 보이지 않는다

## R7-1. 체성분과 마지막 기록 구간 (D11, 2026-10-25 사람 결정)

```swift
enum BodyMetric { case weight, bodyFat, leanMass }
func metricSamples(_ samples: [WeightSampleSnapshot], metric: BodyMetric) -> [WeightSampleSnapshot]  // 값을 kilograms 자리에 넣은 사본
func latestReading(_ samples: [WeightSampleSnapshot], metric: BodyMetric) -> MetricReading?
func seriesEnd(samples: [WeightSampleSnapshot], weeks: Int, now: Date, calendar: Calendar) -> Date
```

- 체지방률(%)·제지방량(kg)은 체중과 같은 주 평균·추이 계산을 쓴다. 숫자만, 구간 이름·판단 색 없음 (COMPLIANCE.md 2.2)
- `seriesEnd`: 최근 `weeks`주에 측정이 있으면 `now`, 없으면 마지막 측정 시각. 오늘 카드(8주)·기록 탭(12주)·추이 화면(고른 기간, 전체 제외)이 같은 규칙. 옮긴 그래프로는 R8 감량 속도 안내를 하지 않는다

## R18. 패키지 정리 (D9, 2026-10-24 사람 결정 "풀푸시")

```swift
func finishedPackages(doses: [DoseSnapshot], now: Date, calendar: Calendar, limit: Int = 12) -> [PackagePeriod]  // 최근 순
func recentlyFinished(doses:now:calendar:) -> PackagePeriod?   // 오늘 카드: 끝난 지 7일 미만
func summary(package:doses:checks:weights:proteins:sessions:proteinTarget:calendar:) -> PackageSummary
```

- 지금 처방의 취소하지 않은 기록을 투약 시각 순으로 4회씩 묶는다 (패키지 = 4회 = 약 한 달, R13-1). 4회가 다 찬 묶음만
- 기간 `[첫 투약일 0시, 마지막 투약일 + 7일)`. 다음 묶음의 첫 투약일이 더 이르면 그날 0시까지 (겹치지 않게). 끝난 것만
- 숫자는 R16과 같다. 평가·지난 패키지와의 비교 없음. 제목은 1회용 펜이면 "패키지 n", 아니면 "a–b회차"

## R19. 증상 흐름 (D9, 2026-10-24 사람 결정 "풀푸시")

```swift
func recentPeriods(prescription: PrescriptionSnapshot, now: Date, calendar: Calendar, count: Int = 8) -> [DateInterval]  // 오래된 순, 마지막은 진행 중
func flows(periods: [DateInterval], checks: [ConditionCheckSnapshot]) -> [SymptomFlow]
```

- 구간은 R16과 같은 7일씩, 최근 8개(지금 구간 포함)
- 증상마다 구간별 가장 강하게 기록한 강도(0~3). 강도 1 이상이 한 번이라도 있는 증상만, 기록된 구간이 많은 순(같으면 증상 목록 순)
- "물어볼 것에 넣기"는 사실 문장만 채운다. 원인·대처·괜찮은지 판단을 붙이지 않는다 (COMPLIANCE.md 2.1-7)

## R20. 마선생 한마디 (D12, 2026-10-25 사람 결정)

```swift
func line(dailyLine: DailyLine?, isLowCondition: Bool, isLowAppetite: Bool, proteinEntriesToday: Int, strengthThisWeek: Int, now: Date, calendar: Calendar) -> CoachLine
```

- 하나만, 우선순위: R17 사실 한 줄 > R11 저컨디션 > R10 식욕 저하 > 12시 이후 오늘 단백질 기록 없음 > 주 시작부터 4일 이상 지났고 이번 주 근력 기록 없음 > 일반 한마디(1년 중 날짜 % 8)
- 과정만 권한다. 체중 숫자·감량을 평가하거나 칭찬하지 않는다 (COMPLIANCE.md 3.1). 다음 부위를 권하지 않는다 (R6)
- 식욕 저하·근력, 일반 한마디 중 단백질·물·근력·수면은 건강관리 정보로 보고 "의사와 상의하세요" 고지를 붙인다 (`isHealthTip`)
- N-F4 (2026-10-29): 다음 진료일이 오늘·어제이고 그날 진료 기록이 없으면 식욕 저하 다음 순서로 "진료 기록을 남겨 둘까요" (`clinicNeedsRecord`, 생각하는 얼굴). 진료 탭 자리·말 걸기 "진료 준비는요"에서도 먼저

### R20-1. 자리별 한마디 (D18)

```swift
func lines(for spot: CoachSpot, context: CoachContext, now: Date, calendar: Calendar) -> [CoachLine]
func next(for spot: CoachSpot, context: CoachContext, shownKeys: Set<String>, now: Date, calendar: Calendar) -> CoachLine?
```

- 오늘 맨 위(`todayTop`): 위 R20 한 줄
- 남은 펜: 남은 회차 사실(R17) > "남은 펜 수를 진료 전에 한 번 보아 두면…"
- 체중: 체중 기록 없음(R17) > 같은 조건에서 재기·오르내림은 자연스럽다 (날짜로 순서 바꿈). 체중 숫자를 평가하지 않는다
- 오늘의 마디: 식욕 저하 > 저컨디션 > 오후 단백질 기록 전 > 단백질·물·수면 일반 한마디
- 맨몸 근력: 이번 주 근력 기록 없음 > 작은 동작부터
- 알아 두기: 물어볼 것 적기 > 기록은 짧아도 괜찮다
- 기록 탭: "지난 기록은 진료 때 의사와 함께 보기 좋아요", 리포트 탭: "진료 며칠 전에 리포트를 미리…"
- `next`는 오늘 이미 띄운 키(`CoachLine.key`)를 빼고 첫 줄. 없으면 nil

### R20-3. 표정과 기록 직후 한마디 (D19)

- `CoachLine.mood`: 기록 직후 → 기쁨, 저컨디션·식욕 저하·컨디션 대답 → 다정, 남은 회차·펜·리포트·물어볼 것·진료 대답 → 생각, 기록 짧아도·물·오르내림·물 대답 → 윙크, 그 밖 → 웃음
- `CoachLine.recorded(kind)`: 투약·컨디션·체중·단백질·운동. 사실과 다음 과정만 말하고 결과를 평가하지 않는다 (체중 "체중 기록했어요.")

### R20-2. 말 걸기 대답 (D18)

```swift
func reply(to topic: CoachTopic, context: CoachContext, shownKeys: Set<String>, now: Date, calendar: Calendar) -> CoachLine
```

- 오늘 뭐부터: R20 한 줄 > 기록 짧아도 / 물 한 잔
- 단백질: 식욕 저하 > 오후 단백질 기록 전 > 나눠 먹기 / 물
- 운동: 저컨디션 > 이번 주 근력 기록 없음 > 작은 동작 / 수면
- 진료 준비: 남은 회차 사실 > 물어볼 것 적기 > 리포트 > 기록 보기
- 한마디 더: 오늘 날짜부터 일반 한마디를 차례로
- D19 물: 물 한 잔 > 자주 조금씩(건강관리) > 습관 체크 '수분' / 잠: 수면 리듬 > 화면 일찍 내려놓기(건강관리) > 습관 체크 '수면' / 체중: 기록 없음 > 같은 조건 > 오르내림 > 체중 추이 보는 법 / 컨디션: 저컨디션 > 24·48시간 칸 > 증상 흐름 > 의사와 상의
- 이번 대화에서 한 줄은 건너뛰고, 다 했으면 처음 줄로 (빈 대답 없음). 말투는 화면이 3가지 중 하나를 고른다 (`variantCount`)

## R21. 검사 결과 (D20, 2026-10-27 사람 결정)

```swift
func lines(from boxes: [TextBox]) -> [String]
func candidates(lines: [String]) -> [LabCandidate]
func latestByItem(_ results: [LabResultSnapshot], limit: Int?) -> [LabResultSnapshot]
func history(of itemKey: String, in results: [LabResultSnapshot]) -> [LabResultSnapshot]
```

- 글자 조각은 세로 가운데가 글자 높이의 절반 안이면 같은 줄, 왼쪽부터 잇는다
- 줄에서 항목 이름(`LabItem.aliases`, 당화혈색소를 혈색소보다·LDL/HDL을 총콜레스테롤보다 먼저)을 찾고, 이름 뒤 첫 숫자를 값으로. 이름 바로 뒤 괄호 안 숫자는 건너뜀. 숫자가 없으면 다음 줄이 숫자로 시작할 때 그 숫자. 영문 이름은 앞뒤가 영문자·숫자가 아닐 때만. 항목마다 처음 하나
- 단위는 줄에 알려진 단위가 있으면 그것, 없으면 항목 기본 단위. 후보는 사용자가 확인한 뒤에만 저장
- N-C1 (2026-10-29): 값을 찾기 전에 단위 글자를 지운다(eGFR 단위의 "1.73"을 값으로 읽지 않게). 소수점이 쉼표인 "5,8"은 5.8, 천 단위 "1,234"는 1234. 약어 별칭 추가 (T-CHOL·TC·CHOL, LDL-C·HDL-C, TRIG, CREA·CRE, Hgb, Vit D, FPG, γ-GT·GGTP)
- 최근 값: 항목(직접 입력은 이름)별 가장 최근, 최근 날짜 순. 리포트는 6개, 오늘 이후 날짜 제외
- 기준 범위·정상/높음·색·추세 평가 없음 (COMPLIANCE.md 2.2)

## R22. 사진으로 단백질 확인 (D20)

- 이미지 분류 이름(확신도 0.12 이상)에 `FoodPhotoRules.keywords`가 들어 있으면 그 식품. N-C2: 한식에서 흔한 이름(scrambled·frittata, squid·shrimp·clam 등 해산물 → 생선, short_rib·brisket → 소고기, pork_chop·tonkatsu·cutlet → 돼지고기, natto·hummus → 콩)까지. 식품별 가장 높은 확신도, 높은 순 3개까지
- 단위: R9 표 1회 기준 그대로(계란 1개 6 g, 두부 반 모 12 g, 닭가슴살 100g 23 g …). 요거트는 컵(150g) 15 g 또는 숟갈(약 15 g) 1.5 g, 콩·두유는 컵 8 g 또는 숟갈 0.5 g. 처음 양은 1(숟갈은 5)
- 대략 g = Σ 단위 g × 양, 반올림. 사진으로 양·칼로리를 판정하지 않는다 (COMPLIANCE.md 2.1-3·2.1-6)

## R23. 기록 탭 날짜 표시 (D20)

- 주는 달력 firstWeekday부터 7일. 날마다 투약(취소 제외)·진료·컨디션·체중·단백질·운동 기록이 있는지만. 많고 적음·연속일 없음
- N-E1 월 보기: `monthGrid`는 그 달을 주 단위 7칸으로, 그 달이 아닌 칸은 nil. 투약일만 표시

## R24. 펼침 배치 (D21, 2026-10-27 사람 요청)

```swift
func isUnfold(from old: CGSize, to new: CGSize) -> Bool
func columns(for size: CGSize) -> Int
```

- 펼침 = 폭이 1.3배 이상 늘고 높이는 20% 안에서 유지. 회전(폭·높이 맞바뀜)·접기·처음 배치는 아니다
- 2단 = 폭 > 높이이고 폭 640pt 이상. 그 밖은 1단
- 유지 1초(`holdSeconds`), 풀기 0.8초(`unfoldSeconds`, 곡선 0.2·0·0·1, 오버슈트 없음)
- D23 (2026-10-30 사람 요청 "듀오 UI 최적화"): 같은 단 수 규칙을 기록·진료·리포트 탭에도 쓴다 (`UnfoldColumns`). 펼친 안쪽 화면은 iPhone Duo가 앱의 지원 방향을 따르지 않으므로 방향이 아니라 크기(폭·높이)로만 판단한다
- D23-1 `tabRailEdge(safeAreaTop:leading:trailing:)`: 위 여백 < 24pt이고 한쪽 옆 여백 ≥ 32pt, 반대쪽 < 16pt이면 상태 표시줄이 옆 기둥에 있는 접힌 화면으로 보고 기둥 반대쪽(`.leading`/`.trailing`)에 탭 레일. 양쪽이 같이 크면(보통 폰 가로) nil



- [x] R1 주 경계·월 경계·연 경계·DST 없음(한국) 검증, 시작일이 예정 요일과 같은 날인 경우
- [x] R2 예정 시각 직전·직후 `.due`/`.overdue` 전환
- [x] R3 과거 Dose 추가로 누락 해제
- [x] R3-1 앞선 누락만 세기, 남은 회차까지만 켜기, 시간 순 회차와 뒤 기록 밀기, 취소 기록 제외 (`BackfillRulesTests`, `BackfillModelTests`)
- [x] R6 부위 기록 없음은 바디맵 이력·부위별 날짜에서 제외 (`SiteRulesTests`)
- [x] R16 구간 경계·끝난 구간만·숫자 집계, R17 우선순위 (`WeeklySummaryRulesTests`, `DailyLineRulesTests`, `TodayModelTests`)
- [x] R7-1 마지막 기록 구간으로 옮기기·체성분 값 고르기·가장 최근 값 (`WeightRulesTests`, `TodayModelTests`), 체지방률 같은 날 붙이기 (`M2ReportAndHealthTests`)
- [x] R20 우선순위·정오 기준·주 후반 기준·날짜로 돌리기·건강관리 고지 표시, R20-1 자리별 후보·이미 띄운 줄 건너뛰기, R20-2 상황 우선·다시 물으면 다음 줄·처음으로 돌아가기, R20-3 새 주제·표정·고지 (`CoachRulesTests`)
- [x] R18 4회째 다음 주까지·덜 찬 묶음 제외·다음 묶음이 일찍 시작하면 자르기·오늘 카드 7일 (`PackageSummaryRulesTests`, `TodayModelTests`), R19 지금 구간까지·구간별 최대 강도·정렬 (`SymptomFlowRulesTests`)
- [x] R21 글자 줄 묶기·이름 뒤 숫자·괄호·다음 줄·영문 경계·최근 값 (`LabRulesTests`, `ReportBuilderTests`), R22 이름 → 식품·단위 g (`FoodPhotoRulesTests`), R23 주 7일·날짜 표시 (`HistoryDayRulesTests`)
- [x] R24 펼침 판정·회전 제외·단 수 (`UnfoldRulesTests`)
- [x] R15 입력 정리, 아직 묻지 않은 것 순서, 리포트 5개·메모와 합쳐 8줄 (`ClinicQuestionRulesTests`, `ReportBuilderTests`)
- [x] R4 4주 제한, 재등록 시 중복 없음
- [x] R5 창 경계값 (12h, 36h, 96h)
- [x] R7 샘플 없는 주 nil 처리
- [x] R8 정확히 -1.0 kg일 때 안내 없음 (초과만), 기준은 % 아닌 kg
- [x] R9 소수점 반올림
- [x] R13 처방 전환 시 이전 처방 endDate·isActive 갱신, 기간 경계에 걸친 처방의 isFirstInPeriod (D4-a·b, `ServiceTests`·`PrescriptionRulesTests`), 가져오기 규칙 7 `resolvingActive` (D4-E1)
