# EXPORT_FORMAT — 데이터 내보내기·가져오기 JSON

설정 > 데이터 > "전체 내보내기"가 만드는 파일의 스키마입니다. 용도는 두 가지입니다.

1. **기기 교체** — iCloud 동기화를 켜기 전까지 유일한 이동 수단. 내보내기 → AirDrop/파일 → 새 기기에서 가져오기
2. **사용자 소유권** — 건강 기록을 언제든 사람이 읽을 수 있는 형식으로 꺼낼 수 있어야 한다는 원칙

리포트 PDF와 달리 무료 기능입니다. 결제 게이트를 두지 않습니다.

## 파일

- 확장자 `.masense.json`, UTType `com.puertpoyo.masense.export` (Info.plist `UTExportedTypeDeclarations`에 선언, `conformsTo: public.json`)
  - 선언 위치: `Config/Masense-Info.plist` (`INFOPLIST_FILE`, 나머지 키는 Xcode가 생성해 합친다)
  - iOS는 마지막 확장자(`json`)로 파일 형식을 정하므로 공유·파일 앱에서는 일반 JSON으로 보인다. 가져오기 파일 선택기는 `.json`도 받는다
- 파일명 `Masense_Export_2026-10-21.masense.json`
- 인코딩 UTF-8, 날짜는 ISO 8601 with fractional seconds + 타임존 오프셋 (`2026-10-21T20:00:00.000+09:00`)
- `JSONEncoder.outputFormatting = [.sortedKeys, .prettyPrinted]` — 사람이 열어 읽을 수 있게
- 압축 없음. 12개월 기록이 수백 KB 수준

## 최상위 구조

```json
{
  "format": "masense-export",
  "formatVersion": 1,
  "appVersion": "1.0.0 (12)",
  "schemaVersion": "1.0.0",
  "exportedAt": "2026-10-21T08:30:00.000+09:00",
  "device": { "model": "iPhone16,2", "systemVersion": "18.1" },
  "settings": { ... },
  "prescriptions": [ ... ],
  "doses": [ ... ],
  "conditionChecks": [ ... ],
  "weightSamples": [ ... ],
  "proteinEntries": [ ... ],
  "strengthSessions": [ ... ],
  "habitChecks": [ ... ],
  "clinicQuestions": [ ... ],
  "clinicVisits": [ ... ],
  "labResults": [ ... ]
}
```

- `format`은 항상 `"masense-export"`. 가져오기 시 첫 검사
- `formatVersion`은 **이 문서의 버전**. 스키마 버전(`schemaVersion`)과 별개로, 파일 구조가 바뀔 때만 올림
- 관계는 중첩이 아니라 **ID 참조**로 평탄화. `doses[].prescriptionId`, `conditionChecks[].doseId`
- M2 이전 빌드가 만든 파일은 `proteinEntries` 등이 빈 배열 또는 키 없음. 가져오기는 둘 다 허용. D6 이전 빌드가 만든 파일은 `clinicQuestions` 키가 없다 (빈 배열로 읽음). D20 이전 빌드가 만든 파일은 `clinicVisits`·`labResults` 키가 없다 (빈 배열로 읽음, formatVersion 1 그대로: D6와 같이 키 추가만)
- `clinicVisits[]`: `id, visitedAt, note, createdAt`. `labResults[]`: `id, visitId(null 가능), measuredAt, item(LabItem rawValue), customName, value, unit, note, createdAt`. 검사지 사진(`ClinicPhoto`)은 담지 않는다

## 레코드 형식

각 레코드는 `DATA_MODEL.md`의 필드를 camelCase 그대로 쓰고, `xxxRaw` 저장 필드는 `Raw` 접미사를 떼고 rawValue 문자열로 내보낸다 (`siteRaw` → `"site": "abdomenUpperLeft"`). 투약의 `site`는 부위 기록 없음이면 `"unknown"` (D6, 형식 v1 안에서 값만 늘어남. 이전 앱은 모르는 값을 그대로 저장하고 부위 기록 없음으로 읽는다).

### settings
```json
{
  "hasAcceptedRoleNotice": true,
  "hasConfirmedAdult": true,
  "reminderEnabled": true,
  "eveningReminderHour": 20,
  "conditionCheckEnabled": true,
  "clinicReminderDaysBefore": 1,
  "exhaustionReminderDosesLeft": 2,
  "proteinTargetGrams": 110,
  "bodyWeightForGuideKg": null,
  "reportTheme": "midnight",
  "reportDefaultPeriod": null,
  "heightCm": 170.5,
  "weightReminderEnabled": true,
  "weightReminderWeekday": null,
  "weightReminderHour": 8,
  "weightReminderMinute": 0
}
```
`healthKitAuthorized`, `hasPurchasedPro`는 **내보내지 않는다** — 기기·계정에 종속. 가져온 뒤 HealthKit은 다시 권한 요청, 구매는 StoreKit 복원.
`reportDefaultPeriod`(D3, 리포트 기본 기간)와 `heightCm`(D5, 키, SchemaV2)는 출시 전 v1 초판에 포함. 키가 없는 파일은 `null`로 읽는다 (formatVersion은 그대로 1).
`weightReminder*`(D7, 체중 기록 알림, SchemaV4)도 같은 버전 안의 추가. 키가 없는 파일을 교체 가져오기하면 기본값(켜짐, 요일 null = 투약 요일, 8:00)이 된다.

비어 있는 값은 키를 지우지 않고 `null`로 쓴다 (모든 레코드 공통). 가져오기는 키 없음과 `null`을 같게 본다.

### prescriptions[]
```json
{
  "id": "6F9619FF-8B86-D011-B42D-00C04FC964FF",
  "startDate": "2026-09-04T00:00:00.000+09:00",
  "endDate": null,
  "penCount": 2,
  "dosesPerPen": 4,
  "intervalDays": 7,
  "scheduledWeekday": 5,
  "scheduledHour": 20,
  "scheduledMinute": 0,
  "nextClinicDate": "2026-10-28T00:00:00.000+09:00",
  "doseLabel": "두 번째 단계",
  "isActive": true,
  "createdAt": "2026-09-04T10:12:00.000+09:00"
}
```

### doses[]
```json
{
  "id": "...",
  "prescriptionId": "6F9619FF-...",
  "administeredAt": "2026-10-16T20:05:00.000+09:00",
  "scheduledFor": "2026-10-16T20:00:00.000+09:00",
  "site": "thighLeft",
  "sequence": 7,
  "note": null,
  "isCancelled": false,
  "createdAt": "..."
}
```

### conditionChecks[]
```json
{
  "id": "...",
  "doseId": "...",
  "checkedAt": "2026-10-17T21:00:00.000+09:00",
  "window": "h24",
  "symptoms": [ { "symptom": "nausea", "severity": 2 }, { "symptom": "fatigue", "severity": 1 } ],
  "appetite": "reduced",
  "note": null,
  "createdAt": "..."
}
```

### weightSamples[]
```json
{
  "id": "...",
  "measuredAt": "2026-10-17T07:10:00.000+09:00",
  "kilograms": 78.4,
  "source": "healthKit",
  "healthKitUUID": "...",
  "leanBodyMassKg": null,
  "bodyFatPercent": null,
  "createdAt": "..."
}
```
`bodyFatPercent`(D11, 체지방률 0~100, SchemaV5)는 같은 버전 안의 추가. 키가 없는 파일은 `null`로 읽는다 (formatVersion은 그대로 1).
`source == "healthKit"`인 샘플은 **가져오기 시 복원하지 않는다.** 새 기기에서 HealthKit을 다시 읽으면 같은 샘플이 들어오므로 중복이 생긴다. 내보내기에는 포함(사람이 읽는 기록으로서), 가져오기는 `manual`만.
`strengthSessions[]`의 `source == "healthKit"`(Apple Watch 운동)도 같은 이유로 가져오지 않는다 (2026-10-22 구현 결정). 결과 화면에는 건너뜀이 아니라 "건강 앱에서 다시 읽음" 건수로 따로 보인다.

### proteinEntries[], strengthSessions[], habitChecks[] (M2)
DATA_MODEL 필드 그대로. `foods`는 rawValue 문자열 배열.

### clinicQuestions[] (D6)
`id`, `text`, `askedAt`(null이면 아직 묻지 않음), `createdAt`. 가져오기는 규칙 5(같은 `id` 건너뜀)만 적용. 배열 추가라 `formatVersion`은 그대로 1 (이전 앱은 모르는 키를 무시한다).

rawValue는 문자열 그대로 옮긴다. 앱이 모르는 값(다음 버전이 더한 부위 등)이 와도 파일을 거부하지 않고 그대로 저장하며, 화면은 모델의 기본값 규칙(DATA_MODEL.md)으로 읽는다. 예외로 `symptoms[].symptom`은 저장 형식이 열거형이라 모르는 증상은 빠진다.
날짜는 소수 초 없는 ISO 8601(`2026-10-21T20:00:00+09:00`)과 `Z` 표기도 읽는다 (사람이 고친 파일).

## 가져오기 규칙

1. `format != "masense-export"` → 거부, "마선생 내보내기 파일이 아닙니다"
2. `formatVersion > 앱이 아는 최대 버전` → 거부, "앱을 업데이트한 뒤 가져오세요"
3. `formatVersion < 현재` → 마이그레이션 함수 체인 (`ExportMigration.v1to2(...)`) 적용 후 진행. 마이그레이션은 순수 함수, 테스트 대상
4. **병합 방식 선택**: "현재 기록을 모두 지우고 교체" / "기존 기록에 추가". 기본은 교체, 2단계 확인
   - 교체: 기록 레코드를 모두 지우고 파일의 `settings` 값을 이 기기 설정 레코드에 덮어쓴다. `healthKitAuthorized`·`hasPurchasedPro`는 그대로, 이 기기에서 이미 마친 온보딩 확인(`hasAcceptedRoleNotice`, `hasConfirmedAdult`)은 되돌리지 않는다
   - 추가: 이 기기의 설정을 그대로 둔다 (2026-10-22 구현 결정)
5. 추가 모드에서는 `id`가 같은 레코드는 건너뜀 (덮어쓰지 않음). ID는 CloudKit 규칙상 unique 제약이 없으므로 가져오기 전에 조회로 확인. 파일 안에서 같은 `id`가 겹치면 처음 것만 넣는다
6. 참조 무결성: `doses[].prescriptionId`가 파일 안에 없으면 그 Dose는 건너뛰고 건수를 결과에 보고. 앱이 임의로 처방을 만들어 붙이지 않음
   - 추가 모드에서 처방이 이미 있어 건너뛰었으면, 그 처방에 딸린 투약은 이 기기의 같은 처방에 붙는다
   - `conditionChecks[].doseId`는 파일 안에서 살아남은 투약(위 규칙을 통과한 것)을 가리켜야 한다. 아니면 건너뜀
7. 활성 처방이 둘 이상이면 `startDate`가 가장 늦은 것만 `isActive = true`, 나머지는 `endDate` 보정. 추가 모드에서는 이 기기의 처방까지 함께 본다. `endDate`가 비어 있으면 다음 처방 시작 전날(자기 시작일보다 앞서지 않게)로 채운다 — `Prescription.activate`와 같은 규칙, `PrescriptionRules.resolvingActive`
8. 가져오기 완료 후 알림 전부 재등록 (R4), HealthKit 캐시 재동기화
9. 결과 화면: 레코드 종류별 가져온 수, 건너뛴 수. "기록했습니다." 톤 유지, 성공 애니메이션 없음

## 구현 위치

- `Services/ExportService.swift` — `writeExportFile(context:now:calendar:) -> URL`, `importFile(at:mode:context:calendar:) -> ImportResult` (`import`는 Swift 예약어라 이름을 바꿈), 알림 재등록·HealthKit 재동기화(규칙 8)는 부르는 화면이 한다
- `Rules/ExportCodec.swift` — `ExportDocument: Codable` 구조체가 이 문서의 형식 정의. 인코딩·디코딩·버전 확인(규칙 1~3)과 가져오기 계획(규칙 4~6, `importPlan`)은 순수 함수
- `Models/ExportRecords+Models.swift` — 모델 ↔ DTO 변환. `Rules/`는 Foundation만 쓰므로(CLAUDE.md) SwiftData에 닿는 변환은 `Snapshots+Models.swift`처럼 Models에 둔다
- `Rules/ExportMigration.swift` — 버전 간 마이그레이션. JSON 객체(`[String: Any]`) 단위로 한 단계씩 고친 뒤 현재 `ExportDocument`로 읽는다
- 테스트: 고정 샘플 파일 `MasenseTests/Fixtures/export_v1.masense.json`으로 round-trip (내보내기 → 가져오기 → 동일) 검증. `formatVersion`을 올릴 때마다 이전 버전 fixture를 추가하고 마이그레이션 테스트

## 보안·프라이버시

- 파일은 평문. 사용자가 공유 시트로 내보내는 순간부터 사용자 책임임을 내보내기 전 한 줄 안내: "이 파일에는 투약과 건강 기록이 담깁니다. 안전한 곳에 보관하세요."
- 암호화·비밀번호 보호는 v1 범위 밖. 요청이 많으면 v2에서 `.masense.enc` 별도 포맷으로
- 파일에 약물명·상표명 없음 (`doseLabel`은 사용자 입력이므로 예외 — 앱이 생성한 문자열이 아님)

## 버전 이력

| formatVersion | 날짜 | 변경 |
|---|---|---|
| 1 | 2026-10-21 | 초판. SchemaV1 전체 + M2 배열(비어 있을 수 있음) |
| 1 | 2026-10-23 | 같은 버전 안에서 추가: `clinicQuestions` 배열(키가 없으면 빈 배열), 투약 `site`의 `"unknown"`(부위 기록 없음), `settings.weightReminder*`. 이전 파일·이전 앱과 서로 읽힌다 |
