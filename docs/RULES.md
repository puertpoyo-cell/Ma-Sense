# RULES — 비즈니스 규칙

`Masense/Rules/`의 순수 함수 사양입니다. 모든 함수는 `Calendar`와 `now: Date`를 인자로 받고, SwiftUI·SwiftData를 import하지 않으며, 각 규칙에 단위 테스트가 있어야 합니다.

## R1. 마디(Cycle) 계산

```swift
struct Cycle { let index: Int; let scheduledDate: Date; let interval: DateInterval }
func cycles(for p: PrescriptionSnapshot, until end: Date, calendar: Calendar) -> [Cycle]
```

- 첫 마디 `scheduledDate` = `startDate` 이후 첫 `scheduledWeekday` + `scheduledHour`:`scheduledMinute`
- 이후 마디 = 이전 + `intervalDays`
- 마디 구간 `interval` = `[scheduledDate - 2일, scheduledDate + intervalDays - 2일)` — 예정일 이틀 전부터 그 마디로 본다 (미리 맞는 경우 수용)
- `totalDoses` 개수만큼 생성. 처방이 소진되면 그 이후 마디는 만들지 않음

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

## R4. 알림 스케줄

```swift
func notificationPlan(p: PrescriptionSnapshot, settings: SettingsSnapshot, doses: [DoseSnapshot], now: Date, calendar: Calendar) -> [PlannedNotification]
```

| 종류 | 시점 | 조건 | 문구 키 |
|---|---|---|---|
| 투약 | 마디 `scheduledDate` | 그 마디에 Dose 없음 | `notif.dose.due` "오늘은 투약일입니다" |
| 저녁 리마인드 | 같은 날 `eveningReminderHour`:00 | 여전히 Dose 없음, `scheduledHour` < eveningReminderHour | `notif.dose.evening` "아직 기록이 없습니다" |
| 컨디션 24h | Dose.administeredAt + 24h | `conditionCheckEnabled`, 해당 window 체크 없음 | `notif.condition.h24` "투약 후 하루, 컨디션을 기록해 주세요" |
| 컨디션 48h | + 48h | 동일 | `notif.condition.h48` |
| 진료 | `nextClinicDate - clinicReminderDaysBefore` 09:00 | nextClinicDate 있음 | `notif.clinic.soon` "내일 진료입니다. 리포트를 준비해 두세요" |
| 소진 | 다음 투약 알림과 함께 | `remainingDoses <= exhaustionReminderDosesLeft` | `notif.prescription.low` "남은 회차가 n회입니다. 진료 예약을 확인하세요" |

- 로컬 알림은 iOS 제한(64개) 때문에 **앞으로 4주치**만 등록하고, 앱이 포그라운드로 올 때마다 전부 취소 후 재등록
- Dose를 기록하면 그 마디의 투약·저녁 알림을 즉시 제거
- 알림 문구에 약 이름·용량 없음

## R5. 컨디션 체크 윈도우

```swift
func openConditionWindows(dose: DoseSnapshot, checks: [ConditionCheckSnapshot], now: Date) -> [ConditionWindow]
```

- `.h24`: `administeredAt + 12h ≤ now < administeredAt + 36h`, 아직 h24 체크 없음
- `.h48`: `administeredAt + 36h ≤ now < administeredAt + 96h`, 아직 h48 체크 없음
- 창이 닫히면 홈에서 사라지고, 기록 화면에서는 "지난 체크"로 추가 입력 가능 (리포트에는 포함)

## R6. 바디맵 표시

```swift
func siteHistory(doses: [DoseSnapshot], limit: Int = 4) -> [(BodySite, Date)]
```

- 최근 4회 사용 부위와 날짜를 돌려줌. UI는 최근 순으로 진하게 표시
- **추천하지 않는다.** "다음은 왼쪽 허벅지" 같은 제안 없음. 사용자가 보고 고름

## R7. 체중 추이

```swift
func weeklyWeightSeries(samples: [WeightSample], weeks: Int, now: Date, calendar: Calendar) -> [WeekPoint]
struct WeekPoint { let weekStart: Date; let averageKg: Double?; let sampleCount: Int }
```

- 주 단위 평균. 샘플 없는 주는 `nil`로 두고 선을 끊음 (보간 금지)
- 같은 날 여러 샘플이면 평균

## R8. 감량 속도 안내 (M2)

```swift
func paceNotice(series: [WeekPoint]) -> PaceNotice?
enum PaceNotice { case fasterThanGeneralGuide }
```

- 최근 2주 연속으로 주당 변화율이 **-1.0%** 를 넘으면(즉, 더 빠르게 감소) `.fasterThanGeneralGuide`
- 문구: "최근 체중 변화가 일반 권고 범위(주 0.5~1%)보다 빠릅니다. 진료 때 상의해 보세요."
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
- 끼니를 비워도 "건너뜀"이라는 단어·아이콘을 쓰지 않는다. 비어 있을 뿐

## R11. 근력운동 마디 (M2)

```swift
func strengthWeekSummary(sessions: [StrengthSession], weekOf: Date, calendar: Calendar) -> StrengthWeek
struct StrengthWeek { let strengthCount: Int; let lightCount: Int; let restCount: Int }
```

- 주간 목표 수치를 화면에 띄우지 않는다. "이번 주 근력 2회" 같은 사실만
- 최근 48h 컨디션에 심각도 2 이상 증상이 있으면 운동 기록 화면에서 걷기·스트레칭·쉬기를 상단에 배치 (R10과 같은 조건 함수 공유: `isLowConditionDay`)

## R12. 리포트 기간

- 기본: `nextClinicDate`가 있으면 직전 진료일(이전 처방 startDate) ~ 오늘, 없으면 최근 8주
- 사용자가 4·8·12주 중 선택 가능
- 리포트 생성 시각과 기간을 PDF 하단에 명시

## R13. 처방 소진 추정

```swift
func exhaustionEstimate(p: PrescriptionSnapshot, doses: [DoseSnapshot], calendar: Calendar) -> Date?
```

- `remainingDoses == 0` → nil
- 그 외 다음 마디부터 `remainingDoses`개째 마디의 `scheduledDate`

## 테스트 체크리스트

- [ ] R1 주 경계·월 경계·연 경계·DST 없음(한국) 검증, 시작일이 예정 요일과 같은 날인 경우
- [ ] R2 자정 직전·직후 `.due`/`.overdue` 전환
- [ ] R3 과거 Dose 추가로 누락 해제
- [ ] R4 4주 제한, 재등록 시 중복 없음
- [ ] R5 창 경계값 (12h, 36h, 96h)
- [ ] R7 샘플 없는 주 nil 처리
- [ ] R8 정확히 -1.0%일 때 안내 없음 (초과만)
- [ ] R9 소수점 반올림
