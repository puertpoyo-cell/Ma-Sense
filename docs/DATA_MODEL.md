# DATA_MODEL — SwiftData 스키마

모든 모델은 `Masense/Models/`에 두고 이 문서와 1:1로 맞춥니다. 스키마를 바꾸면 이 문서를 먼저 고치고 `SchemaVersion`을 올립니다.

## 원칙

- 온디바이스 전용. `ModelConfiguration(isStoredInMemoryOnly: false, cloudKitDatabase: .none)`
- 모든 모델에 `id: UUID`, `createdAt: Date` 포함
- 날짜는 `Date`로 저장하고 해석은 `Calendar.current` 주입
- 삭제는 소프트 삭제 없이 실제 삭제. 단, `Dose`는 리포트 무결성 때문에 "취소됨" 플래그 사용
- 전문의약품 상표를 식별자·enum case·주석에 쓰지 않는다

## 모델 관계도

```
Prescription 1 ─── * Dose 1 ─── * ConditionCheck
                       │
                       └── BodySite (enum)

ProteinEntry        (날짜 기준 독립)
StrengthSession     (날짜 기준 독립)
HabitCheck          (날짜 기준 독립)
WeightSample        (HealthKit 캐시 + 수동 입력)
UserSettings        (단일 레코드)
```

## 모델 정의

### Prescription — 처방

| 필드 | 타입 | 설명 |
|---|---|---|
| id | UUID | |
| startDate | Date | 처방 시작일 |
| penCount | Int | 처방받은 펜 수 |
| dosesPerPen | Int | 펜당 회차 (기본 4) |
| intervalDays | Int | 투약 간격, 기본 7. UI는 7만 노출 |
| scheduledWeekday | Int | 1(일)~7(토), `Calendar` weekday |
| scheduledHour | Int | 예정 시각 (0~23) |
| scheduledMinute | Int | 예정 분 (0~59) |
| nextClinicDate | Date? | 다음 진료일 |
| doseLabel | String? | 사용자가 적는 자유 메모 ("2.5", "두 번째 단계" 등). 앱은 해석하지 않음 |
| isActive | Bool | 현재 처방 여부. 활성은 항상 1개 |
| doses | [Dose] | `@Relationship(deleteRule: .cascade, inverse: \Dose.prescription)` |
| createdAt | Date | |

파생값 (저장하지 않음, `Rules/`에서 계산):
- `scheduledTime: DateComponents` = `(hour: scheduledHour, minute: scheduledMinute)`. `DateComponents`를 그대로 저장하지 않는 이유는 SwiftData의 Codable 저장이 `calendar`·`timeZone` 같은 중첩 값에서 불안정하기 때문
- `totalDoses = penCount * dosesPerPen`
- `usedDoses = doses.filter { !$0.isCancelled }.count`
- `remainingDoses = totalDoses - usedDoses`
- `estimatedExhaustionDate = startDate + remainingDoses * intervalDays`

### Dose — 투약

| 필드 | 타입 | 설명 |
|---|---|---|
| id | UUID | |
| administeredAt | Date | 실제 투약 시각 |
| scheduledFor | Date | 예정일 (마디 기준점) |
| site | BodySite | 주사 부위 |
| sequence | Int | 처방 내 회차 (1부터) |
| note | String? | 자유 메모 |
| isCancelled | Bool | 잘못 기록 취소용. 리포트에서는 제외 |
| prescription | Prescription? | |
| conditionChecks | [ConditionCheck] | `@Relationship(deleteRule: .cascade, inverse: \ConditionCheck.dose)` |
| createdAt | Date | |

### BodySite — 주사 부위 (enum, Codable, String rawValue)

```swift
enum BodySite: String, Codable, CaseIterable {
    case abdomenUpperLeft, abdomenUpperRight
    case abdomenLowerLeft, abdomenLowerRight
    case thighLeft, thighRight
    case upperArmLeft, upperArmRight
}
```

표시명은 `Localizable.xcstrings`에서. 그룹: `abdomen`, `thigh`, `upperArm`.

### ConditionCheck — 컨디션 체크

| 필드 | 타입 | 설명 |
|---|---|---|
| id | UUID | |
| checkedAt | Date | 응답 시각 |
| window | ConditionWindow | `.h24` 또는 `.h48` |
| symptoms | [SymptomEntry] | Codable 배열로 저장 |
| appetite | AppetiteLevel | `.normal`, `.reduced`, `.veryReduced` |
| note | String? | |
| dose | Dose? | |
| createdAt | Date | |

```swift
enum ConditionWindow: String, Codable { case h24, h48 }

enum Symptom: String, Codable, CaseIterable {
    case nausea, vomiting, constipation, diarrhea
    case fatigue, headache, dizziness
    case injectionSiteReaction
    case heartburn, bloating
}

struct SymptomEntry: Codable, Hashable {
    var symptom: Symptom
    var severity: Int   // 0 없음, 1 약함, 2 보통, 3 심함
}

enum AppetiteLevel: String, Codable { case normal, reduced, veryReduced }
```

심각도 3이 하나라도 있으면 UI는 "심하면 의사와 상담하세요"를 고정 노출. 앱은 그 이상의 판단을 하지 않음.

### WeightSample — 체중

| 필드 | 타입 | 설명 |
|---|---|---|
| id | UUID | |
| measuredAt | Date | |
| kilograms | Double | |
| source | WeightSource | `.healthKit`, `.manual` |
| healthKitUUID | UUID? | HealthKit 샘플 UUID (중복 방지) |
| leanBodyMassKg | Double? | M2, HealthKit `leanBodyMass` 또는 수동 |
| createdAt | Date | |

HealthKit에서 읽은 샘플은 캐시로 저장. 동기화 시 `healthKitUUID` 기준 upsert. HealthKit 샘플이 삭제되면 캐시도 삭제.

### ProteinEntry — 단백질 채우기 (M2)

| 필드 | 타입 | 설명 |
|---|---|---|
| id | UUID | |
| date | Date | 그 날 00:00 (로컬) |
| meal | MealSlot | `.breakfast`, `.lunch`, `.dinner`, `.snack` |
| foods | [ProteinFood] | 체크한 식품들 |
| estimatedGrams | Int | 식품별 기본값 합산. 사용자가 덮어쓸 수 있음 |
| createdAt | Date | |

```swift
enum MealSlot: String, Codable, CaseIterable { case breakfast, lunch, dinner, snack }

enum ProteinFood: String, Codable, CaseIterable {
    case egg, tofu, chickenBreast, greekYogurt, proteinShake
    case fish, beef, pork, beans, milk, cheese, other
    var defaultGrams: Int { /* RULES.md 표 참조 */ }
}
```

### StrengthSession — 근력운동 마디 (M2)

| 필드 | 타입 | 설명 |
|---|---|---|
| id | UUID | |
| startedAt | Date | |
| durationMinutes | Int | |
| kind | SessionKind | `.strength`, `.walk`, `.stretch`, `.rest` |
| intensity | Intensity | `.light`, `.moderate`, `.vigorous` |
| source | SessionSource | `.manual`, `.healthKit` |
| healthKitUUID | UUID? | |
| note | String? | |
| createdAt | Date | |

`.rest`는 "쉬는 날도 기록"을 위해 존재. 리포트의 근력운동 횟수에는 `.strength`만 집계.

### HabitCheck — 기본 습관 (M2, P2)

| 필드 | 타입 | 설명 |
|---|---|---|
| id | UUID | |
| date | Date | 그 날 00:00 |
| water | Bool | |
| fiber | Bool | |
| sleep | Bool | |
| createdAt | Date | |

### UserSettings — 단일 레코드

| 필드 | 타입 | 설명 |
|---|---|---|
| id | UUID | |
| hasAcceptedRoleNotice | Bool | "처방은 의사, 기록은 마선생" 확인 |
| hasConfirmedAdult | Bool | 만 19세 이상 확인 |
| reminderEnabled | Bool | |
| eveningReminderHour | Int | 미기록 리마인드 시각, 기본 20 |
| conditionCheckEnabled | Bool | |
| clinicReminderDaysBefore | Int | 기본 1 |
| exhaustionReminderDosesLeft | Int | 남은 회차가 이 값일 때 진료 예약 알림, 기본 2 |
| proteinTargetGrams | Int? | 사용자/의료진 입력. nil이면 안내만 |
| bodyWeightForGuideKg | Double? | 1.2~1.6 g/kg 안내 계산용. 최근 체중 자동 사용 가능 |
| healthKitAuthorized | Bool | |
| hasPurchasedPro | Bool | StoreKit 검증 결과 캐시. 진실 원천은 StoreKit |
| reportTheme | String | 기본 `"midnight"` |
| reportDefaultPeriod | String? | V3. 리포트 기본 기간 `ReportPeriod.storageValue` (`sinceClinic`, `weeks4`·`weeks8`·`weeks12`). nil이면 자동(R12) |
| createdAt | Date | |

## HealthKit 매핑

| 앱 데이터 | HKQuantityType / HKWorkoutType | 방향 |
|---|---|---|
| WeightSample.kilograms | `bodyMass` | 읽기 (쓰기는 v1.1) |
| WeightSample.leanBodyMassKg | `leanBodyMass` | 읽기 |
| StrengthSession (M2, P2) | `HKWorkoutType` activityType `.traditionalStrengthTraining`, `.functionalStrengthTraining`, `.walking`, `.flexibility` | 읽기 |

Info.plist: `NSHealthShareUsageDescription` 필수 (빌드 설정 `INFOPLIST_KEY_NSHealthShareUsageDescription`, 번역 `InfoPlist.xcstrings`, entitlement `Config/Masense.entitlements`). 쓰기 전까지 `NSHealthUpdateUsageDescription`은 넣지 않음.

- 제지방량은 별도 샘플로 오므로, 같은 날 HealthKit 체중 샘플의 `leanBodyMassKg`에 붙인다 (그날 가장 늦은 값). 같은 날 체중이 없으면 버린다
- 운동은 `StrengthSession(source: .healthKit)`으로 `healthKitUUID` 기준 upsert. 근력(traditional·functional) → `.strength`, 걷기 → `.walk`, 유연성 → `.stretch`, 그 밖은 무시. 강도는 알 수 없어 `.moderate`

## 스키마 버전

```swift
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [
        Prescription.self, Dose.self, ConditionCheck.self,
        WeightSample.self, UserSettings.self
    ]
}
enum SchemaV2: VersionedSchema {   // M2
    static var versionIdentifier = Schema.Version(2, 0, 0)
    // + ProteinEntry, StrengthSession, HabitCheck
}
enum SchemaV3: VersionedSchema {   // 2026-10-22, 리포트 기본 기간 저장
    static var versionIdentifier = Schema.Version(3, 0, 0)
    // UserSettings + reportDefaultPeriod: String?
}
enum MasenseMigrationPlan: SchemaMigrationPlan {
    // [SchemaV1, SchemaV2, SchemaV3], 단계: .lightweight(V1 → V2), .lightweight(V2 → V3)
}
```

- 바뀐 모델은 이전 버전 쪽에 **고정 사본**을 둔다. V1·V2의 `UserSettings`는 `SchemaV1.UserSettings`(V3 이전 저장 속성 그대로)이고, 바뀌지 않은 모델은 현재 타입을 같이 쓴다. 고정 사본의 저장 속성을 고치면 기존 저장소의 버전을 알아보지 못한다
- `MigrationTests`: V1 → V3, V2 → V3 디스크 저장소 마이그레이션

```swift
```

M1 출시 전에는 마이그레이션 없이 스키마 자유 변경. 베타 배포 후부터 `SchemaMigrationPlan` 필수.

## 리포트용 조회 (Rules에서 사용)

- `doses(in: DateInterval)` — `isCancelled == false`, `administeredAt` 범위
- `missedDoses(in:)` — 예정일 기준 `scheduledFor`가 있으나 해당 마디에 Dose 없음 → `RULES.md`의 마디 계산으로 도출 (저장 안 함)
- `symptomFrequency(in:)` — ConditionCheck 집계, 증상별 (발생 건수, 최대 강도)
- `weightTrend(in:)` — 주 단위 평균
- `proteinDaysMet(in:)`, `strengthSessionCount(in:)` — M2
