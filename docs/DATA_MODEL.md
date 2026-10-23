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

- 구현 (D4-A): `App/StoreLocation.swift`가 위치를 정하고 `ModelContainer.masense()`가 쓴다
  - 그룹 컨테이너를 얻지 못하면(App Group 서명이 없는 빌드) 앱 기본 경로 `Application Support/Masense.store`를 그대로 쓴다. `!` 강제 언래핑 대신 이 폴백
  - D4-A 이전 빌드가 앱 기본 경로에 만든 스토어가 있고 그룹 쪽에 스토어가 없으면 첫 실행에 옮긴다. 본 파일과 `-wal`·`-shm`을 모두 복사한 뒤에만 이전 파일을 지우고, 하나라도 실패하면 복사본을 지우고 이전 경로를 쓴다 (`StoreLocationTests`)
- Xcode: 앱 타깃에 App Groups capability 추가 (`Config/Masense.entitlements`의 `com.apple.security.application-groups`), 위젯·Watch 타깃이 생기면 같은 그룹 ID 추가. 개발자 계정에 그룹이 등록되어 있어야 실기기 서명이 된다 (자동 서명이면 Xcode가 등록)
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
| intervalDays | Int | `7` | **v1은 항상 7.** UI·Rules는 주 1회를 전제로 하며 이 값을 읽지 않는다. 필드만 미리 두어 나중에 다른 주기를 열 때 스키마 변경을 피함 |
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
- `estimatedExhaustionDate` = R13 (주 단위 마디 기준)

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
| heightCm | Double? |  | 키(cm). BMI 숫자 계산에만 쓴다(R14). nil이면 BMI를 보이지 않는다. **SchemaV2(1.1.0)에서 추가** (D5, 2026-10-22 사람 결정) |
| healthKitAuthorized | Bool | `false` |  |
| hasPurchasedPro | Bool | `false` | StoreKit 검증 결과 캐시. 진실 원천은 StoreKit |
| reportTheme | String | `"midnight"` |  |
| reportDefaultPeriod | String? |  | 리포트 기본 기간 `ReportPeriod.storageValue` (`sinceClinic`, `weeks4`·`weeks8`·`weeks12`). nil이면 자동(R12) |
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
enum SchemaV1: VersionedSchema {   // 출시 스키마 (2026-10-22 재정리)
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Prescription.self, Dose.self, ConditionCheck.self, WeightSample.self,
         SchemaV1.UserSettings.self, ProteinEntry.self, StrengthSession.self, HabitCheck.self]
    }
    @Model final class UserSettings { ... }   // 1.0.0 고정 사본 (heightCm 없음)
}
enum SchemaV2: VersionedSchema {   // D5: UserSettings.heightCm 추가
    static let versionIdentifier = Schema.Version(1, 1, 0)
    // 나머지 모델은 V1과 같은 타입, UserSettings만 지금 모델
}
typealias CurrentSchema = SchemaV2
enum MasenseMigrationPlan: SchemaMigrationPlan {
    // [SchemaV1, SchemaV2], .lightweight(V1 → V2)
}
```

- **2026-10-22 출시 전 재정리 (사람 결정)**: 개발 중 쌓인 V1(M1)·V2(M2 습관)·V3(리포트 기본 기간) 이력을 접고, CloudKit 호환 규칙(B)과 처방 `endDate`(C)를 담은 새 `SchemaV1` 하나로 시작한다. 출시 전이라 사용자 데이터가 없다
- 개발 빌드(`DEBUG`)는 이전 구조의 저장소를 열지 못하면 지우고 새로 만든다 (`ModelContainer.masense`). 릴리스 빌드는 그러지 않는다
- 출시 뒤 스키마를 바꿀 때: 바뀌는 모델의 **고정 사본**을 이전 버전(`SchemaV1.Xxx`)에 두고 `SchemaV2`와 마이그레이션 단계를 더한다. 고정 사본의 저장 속성은 고치지 않는다(기존 저장소의 버전을 알아보는 기준). CloudKit 규칙 5에 따라 변경은 추가만
- V2 (D5, 2026-10-22 사람 결정): `UserSettings.heightCm` 옵셔널 추가 → 경량 이전. 개발 중 기기에 있는 V1 저장소의 기록을 지우지 않으려고 고정 사본 방식으로 올렸다
- `SchemaTests`: unique 없음, 열거형 rawValue 디스크 왕복, 모르는 rawValue 기본값, 설정 기본값, V1 저장소 → V2 이전

M1 출시 전에는 마이그레이션 없이 스키마 자유 변경. 베타 배포 후부터 `SchemaMigrationPlan` 필수.

## 리포트용 조회 (Rules에서 사용)

- `doses(in: DateInterval)` — `isCancelled == false`, `administeredAt` 범위
- `missedDoses(in:)` — 예정일 기준 `scheduledFor`가 있으나 해당 마디에 Dose 없음 → `RULES.md`의 마디 계산으로 도출 (저장 안 함)
- `symptomFrequency(in:)` — ConditionCheck 집계, 증상별 (발생 건수, 최대 강도)
- `weightTrend(in:)` — 주 단위 평균
- `proteinDaysMet(in:)`, `strengthSessionCount(in:)` — M2
