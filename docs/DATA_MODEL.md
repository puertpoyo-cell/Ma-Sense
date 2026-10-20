# DATA_MODEL — SwiftData 스키마

모든 모델은 `Masense/Models/`에 두고 이 문서와 1:1로 맞춥니다. 스키마를 바꾸면 이 문서를 먼저 고치고 `SchemaVersion`을 올립니다.

## 원칙

### 저장 위치 — App Group 컨테이너

- 스토어 파일은 App Group `group.com.puertpoyo.masense`의 컨테이너에 둔다. 앱 샌드박스 기본 경로를 쓰지 않는다.
- 이유: v2 후보인 잠금화면 위젯·Live Activity·Apple Watch 컴패니언이 **같은 스토어를 읽기만 하면** 되게 하기 위함. 나중에 옮기면 스토어 파일 이전과 사용자 데이터 마이그레이션이 필요하다.
- 구성 예시 (`App/ModelContainer+Masense.swift`):

```swift
let groupID = "group.com.puertpoyo.masense"
let url = FileManager.default
    .containerURL(forSecurityApplicationGroupIdentifier: groupID)!
    .appendingPathComponent("Masense.store")
let config = ModelConfiguration("Masense", schema: schema, url: url,
                                cloudKitDatabase: .none)
```

- Xcode: 앱 타깃에 App Groups capability 추가, 위젯·Watch 타깃이 생기면 같은 그룹 ID 추가
- 쓰기는 앱 타깃만. 위젯 등 익스텐션은 읽기 전용으로 쓰고, 기록 액션은 딥링크로 앱을 연다 (동시 쓰기 회피)
- 테스트·미리보기는 `isStoredInMemoryOnly: true`로 App Group을 쓰지 않는다

### CloudKit 호환 규칙 (v1부터 적용, 동기화는 꺼 둠)

v1은 `cloudKitDatabase: .none`이지만, 기기 교체·분실 대비로 나중에 **개인 iCloud(private database)** 동기화를 켤 수 있도록 스키마를 처음부터 호환되게 잡는다. 개인 iCloud는 사용자 본인 계정에만 저장되므로 "외부 서버 전송 없음" 메시지와 충돌하지 않는다 (켤 때 문구를 "iCloud에 백업됩니다"로 갱신).

SwiftData + CloudKit이 요구하는 제약을 모든 `@Model`에 적용한다:

1. **`@Attribute(.unique)` 금지.** `id: UUID`는 unique 없이 `= UUID()` 기본값으로만 둔다. 중복 방지는 앱 로직에서 (예: `healthKitUUID` 조회 후 upsert).
2. **모든 저장 속성은 기본값이 있거나 옵셔널.** 비옵셔널 `Date`, `Int`, `Bool`, `String`, enum은 반드시 `= 기본값`.
3. **관계는 전부 옵셔널**, to-many는 `[T]? = []` 또는 `[T] = []`. `deleteRule: .cascade`는 허용, `.deny`는 금지.
4. **enum은 `String` rawValue + `Codable`.** 저장은 rawValue로. 배열(`[SymptomEntry]`)은 Codable 구조체 배열로 저장 (SwiftData가 transformable로 처리).
5. 스키마 변경은 **추가만** (필드 추가, 새 모델). 이름 변경·삭제·타입 변경은 CloudKit 스키마와 충돌하므로 새 필드 추가 + 옛 필드 방치로 처리.
6. 컨테이너 ID는 `iCloud.com.puertpoyo.masense`로 예약해 두고, v1에서는 Capability를 켜지 않는다.

아래 표의 "기본값" 열이 이 규칙을 반영한다. 기본값 열이 비어 있으면 옵셔널(`nil`)이다.

### 공통

- 모든 모델에 `id: UUID = UUID()`, `createdAt: Date = .now` 포함
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

| 필드 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| id | UUID | `UUID()` |  |
| startDate | Date | `.now` | 처방 시작일 |
| penCount | Int | `1` | 처방받은 펜 수 |
| dosesPerPen | Int | `4` | 펜당 회차 |
| intervalDays | Int | `7` | 투약 간격, 기본 7. UI는 7만 노출 |
| scheduledWeekday | Int | `5` | 1(일)~7(토), `Calendar` weekday |
| scheduledHour | Int | `20` | 투약 시각 (시) |
| scheduledMinute | Int | `0` | 투약 시각 (분) |
| endDate | Date? |  | 처방 종료일. 새 처방을 시작하면 이전 처방의 endDate = 새 처방 startDate 전날로 자동 설정 |
| nextClinicDate | Date? |  | 다음 진료일 |
| doseLabel | String? |  | 사용자가 적는 자유 메모 ("2.5", "두 번째 단계" 등). 앱은 해석하지 않음 |
| isActive | Bool | `true` | 현재 처방 여부. 활성은 항상 1개 (= `endDate == nil`인 것) |
| doses | [Dose] | `[]` | `@Relationship(deleteRule: .cascade, inverse: \Dose.prescription)` |
| createdAt | Date | `.now` |  |

`scheduledTime: DateComponents`는 CloudKit transformable 처리가 번거로워 `scheduledHour`/`scheduledMinute` 두 Int로 분해했다.

**처방 이력 (체인)**: 처방은 삭제하지 않고 `startDate` 오름차순으로 쌓인다. 별도 `previous` 관계 없이 `startDate`/`endDate`로 시간순을 복원한다. 리포트와 기록 탭은 이 체인에서 "처방 전환 지점"(각 처방의 `startDate`)과 그때의 `doseLabel`을 읽어 표시만 한다 — 앱은 `doseLabel`을 파싱·비교·해석하지 않는다.

파생값: `prescriptionTimeline(in:)` — 기간 안의 처방 목록을 `(startDate, doseLabel?)` 배열로 돌려줌 (`Rules/PrescriptionRules.swift`).

파생값 (저장하지 않음, `Rules/`에서 계산):
- `scheduledTime: DateComponents` = `(hour: scheduledHour, minute: scheduledMinute)`. `DateComponents`를 그대로 저장하지 않는 이유는 SwiftData의 Codable 저장이 `calendar`·`timeZone` 같은 중첩 값에서 불안정하기 때문
- `totalDoses = penCount * dosesPerPen`
- `usedDoses = doses.filter { !$0.isCancelled }.count`
- `remainingDoses = totalDoses - usedDoses`
- `estimatedExhaustionDate = startDate + remainingDoses * intervalDays`

### Dose — 투약

| 필드 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| id | UUID | `UUID()` |  |
| administeredAt | Date | `.now` | 실제 투약 시각 |
| scheduledFor | Date | `.now` | 예정일 (마디 기준점) |
| siteRaw | String | `"abdomenUpperLeft"` | `BodySite` rawValue. 계산 프로퍼티 `site: BodySite`로 접근 |
| sequence | Int | `1` | 처방 내 회차 (1부터) |
| note | String? |  | 자유 메모 |
| isCancelled | Bool | `false` | 잘못 기록 취소용. 리포트에서는 제외 |
| prescription | Prescription? |  |  |
| conditionChecks | [ConditionCheck] | `[]` | `@Relationship(deleteRule: .cascade, inverse: \ConditionCheck.dose)` |
| createdAt | Date | `.now` |  |

### BodySite — 주사 부위 (enum, Codable, String rawValue)

```swift
enum BodySite: String, Codable, CaseIterable {
    case abdomenUpperLeft, abdomenUpperRight
    case abdomenLowerLeft, abdomenLowerRight
    case thighLeft, thighRight
    case upperArmLeft, upperArmRight
}
```

표시명은 `Localizable.xcstrings`에서. 그룹: `abdomen`, `thigh`, `upperArm`. 저장은 `siteRaw: String`이며 모델에 `var site: BodySite { get set }` 계산 프로퍼티를 둔다. 다른 enum(`ConditionWindow`, `AppetiteLevel`, `WeightSource`, `MealSlot`, `SessionKind`, `Intensity`, `SessionSource`)도 같은 패턴(`xxxRaw` 저장 + 계산 프로퍼티).

### ConditionCheck — 컨디션 체크

| 필드 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| id | UUID | `UUID()` |  |
| checkedAt | Date | `.now` | 응답 시각 |
| windowRaw | String | `"h24"` | `ConditionWindow` rawValue |
| symptoms | [SymptomEntry] | `[]` | Codable 배열 (transformable) |
| appetiteRaw | String | `"normal"` | `AppetiteLevel` rawValue |
| note | String? |  |  |
| dose | Dose? |  |  |
| createdAt | Date | `.now` |  |

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

| 필드 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| id | UUID | `UUID()` |  |
| measuredAt | Date | `.now` |  |
| kilograms | Double | `0` |  |
| sourceRaw | String | `"manual"` | `WeightSource` rawValue: healthKit / manual |
| healthKitUUID | UUID? |  | HealthKit 샘플 UUID. unique 제약 없이 조회 후 upsert |
| leanBodyMassKg | Double? |  | M2, HealthKit `leanBodyMass` 또는 수동 |
| createdAt | Date | `.now` |  |

HealthKit에서 읽은 샘플은 캐시로 저장. 동기화 시 `healthKitUUID` 기준 upsert. HealthKit 샘플이 삭제되면 캐시도 삭제.

### ProteinEntry — 단백질 채우기 (M2)

| 필드 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| id | UUID | `UUID()` |  |
| date | Date | `.now` | 그 날 00:00 (로컬) |
| mealRaw | String | `"breakfast"` | `MealSlot` rawValue |
| foodsRaw | [String] | `[]` | `ProteinFood` rawValue 배열 |
| estimatedGrams | Int | `0` | 식품별 기본값 합산. 사용자가 덮어쓸 수 있음 |
| createdAt | Date | `.now` |  |

```swift
enum MealSlot: String, Codable, CaseIterable { case breakfast, lunch, dinner, snack }

enum ProteinFood: String, Codable, CaseIterable {
    case egg, tofu, chickenBreast, greekYogurt, proteinShake
    case fish, beef, pork, beans, milk, cheese, other
    var defaultGrams: Int { /* RULES.md 표 참조 */ }
}
```

### StrengthSession — 근력운동 마디 (M2)

| 필드 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| id | UUID | `UUID()` |  |
| startedAt | Date | `.now` |  |
| durationMinutes | Int | `0` |  |
| kindRaw | String | `"strength"` | `SessionKind`: strength / walk / stretch / rest |
| intensityRaw | String | `"moderate"` | `Intensity`: light / moderate / vigorous |
| sourceRaw | String | `"manual"` | `SessionSource`: manual / healthKit |
| healthKitUUID | UUID? |  |  |
| note | String? |  |  |
| createdAt | Date | `.now` |  |

`.rest`는 "쉬는 날도 기록"을 위해 존재. 리포트의 근력운동 횟수에는 `.strength`만 집계.

### HabitCheck — 기본 습관 (M2, P2)

| 필드 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| id | UUID | `UUID()` |  |
| date | Date | `.now` | 그 날 00:00 |
| water | Bool | `false` |  |
| fiber | Bool | `false` |  |
| sleep | Bool | `false` |  |
| createdAt | Date | `.now` |  |

### UserSettings — 단일 레코드

| 필드 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| id | UUID | `UUID()` |  |
| hasAcceptedRoleNotice | Bool | `false` | "처방은 의사, 기록은 마선생" 확인 |
| hasConfirmedAdult | Bool | `false` | 만 19세 이상 확인 |
| reminderEnabled | Bool | `true` |  |
| eveningReminderHour | Int | `20` | 미기록 리마인드 시각 |
| conditionCheckEnabled | Bool | `true` |  |
| clinicReminderDaysBefore | Int | `1` |  |
| exhaustionReminderDosesLeft | Int | `2` | 남은 회차가 이 값일 때 진료 예약 알림 |
| proteinTargetGrams | Int? |  | 사용자/의료진 입력. nil이면 안내만 |
| bodyWeightForGuideKg | Double? |  | 1.2~1.6 g/kg 안내 계산용. 최근 체중 자동 사용 가능 |
| healthKitAuthorized | Bool | `false` |  |
| hasPurchasedPro | Bool | `false` | StoreKit 검증 결과 캐시. 진실 원천은 StoreKit |
| reportTheme | String | `"midnight"` |  |
| reportDefaultPeriod | String? |  | V3. 리포트 기본 기간 `ReportPeriod.storageValue` (`sinceClinic`, `weeks4`·`weeks8`·`weeks12`). nil이면 자동(R12) |
| createdAt | Date | `.now` |  |

단일 레코드는 CloudKit에서 기기마다 하나씩 생겨 충돌할 수 있다. 동기화를 켤 때는 `createdAt`이 가장 이른 레코드를 정본으로 삼고 나머지를 병합·삭제하는 규칙을 `Rules/SettingsMerge.swift`에 둔다 (v1은 해당 없음).

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
