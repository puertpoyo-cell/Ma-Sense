# EXPORT_FORMAT — 데이터 내보내기·가져오기 JSON

설정 > 데이터 > "전체 내보내기"가 만드는 파일의 스키마입니다. 용도는 두 가지입니다.

1. **기기 교체** — iCloud 동기화를 켜기 전까지 유일한 이동 수단. 내보내기 → AirDrop/파일 → 새 기기에서 가져오기
2. **사용자 소유권** — 건강 기록을 언제든 사람이 읽을 수 있는 형식으로 꺼낼 수 있어야 한다는 원칙

리포트 PDF와 달리 무료 기능입니다. 결제 게이트를 두지 않습니다.

## 파일

- 확장자 `.masense.json`, UTType `com.puertpoyo.masense.export` (Info.plist `UTExportedTypeDeclarations`에 선언, `conformsTo: public.json`)
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
  "habitChecks": [ ... ]
}
```

- `format`은 항상 `"masense-export"`. 가져오기 시 첫 검사
- `formatVersion`은 **이 문서의 버전**. 스키마 버전(`schemaVersion`)과 별개로, 파일 구조가 바뀔 때만 올림
- 관계는 중첩이 아니라 **ID 참조**로 평탄화. `doses[].prescriptionId`, `conditionChecks[].doseId`
- M2 이전 빌드가 만든 파일은 `proteinEntries` 등이 빈 배열 또는 키 없음. 가져오기는 둘 다 허용

## 레코드 형식

각 레코드는 `DATA_MODEL.md`의 필드를 camelCase 그대로 쓰고, `xxxRaw` 저장 필드는 `Raw` 접미사를 떼고 rawValue 문자열로 내보낸다 (`siteRaw` → `"site": "abdomenUpperLeft"`).

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
  "reportTheme": "midnight"
}
```
`healthKitAuthorized`, `hasPurchasedPro`는 **내보내지 않는다** — 기기·계정에 종속. 가져온 뒤 HealthKit은 다시 권한 요청, 구매는 StoreKit 복원.

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
  "createdAt": "..."
}
```
`source == "healthKit"`인 샘플은 **가져오기 시 복원하지 않는다.** 새 기기에서 HealthKit을 다시 읽으면 같은 샘플이 들어오므로 중복이 생긴다. 내보내기에는 포함(사람이 읽는 기록으로서), 가져오기는 `manual`만.

### proteinEntries[], strengthSessions[], habitChecks[] (M2)
DATA_MODEL 필드 그대로. `foods`는 rawValue 문자열 배열.

## 가져오기 규칙

1. `format != "masense-export"` → 거부, "마선생 내보내기 파일이 아닙니다"
2. `formatVersion > 앱이 아는 최대 버전` → 거부, "앱을 업데이트한 뒤 가져오세요"
3. `formatVersion < 현재` → 마이그레이션 함수 체인 (`ExportMigration.v1to2(...)`) 적용 후 진행. 마이그레이션은 순수 함수, 테스트 대상
4. **병합 방식 선택**: "현재 기록을 모두 지우고 교체" / "기존 기록에 추가". 기본은 교체, 2단계 확인
5. 추가 모드에서는 `id`가 같은 레코드는 건너뜀 (덮어쓰지 않음). ID는 CloudKit 규칙상 unique 제약이 없으므로 가져오기 전에 조회로 확인
6. 참조 무결성: `doses[].prescriptionId`가 파일 안에 없으면 그 Dose는 건너뛰고 건수를 결과에 보고. 앱이 임의로 처방을 만들어 붙이지 않음
7. 활성 처방이 둘 이상이면 `startDate`가 가장 늦은 것만 `isActive = true`, 나머지는 `endDate` 보정
8. 가져오기 완료 후 알림 전부 재등록 (R4), HealthKit 캐시 재동기화
9. 결과 화면: 레코드 종류별 가져온 수, 건너뛴 수. "기록했습니다." 톤 유지, 성공 애니메이션 없음

## 구현 위치

- `Services/ExportService.swift` — `export() -> URL`, `import(url:mode:) -> ImportResult`
- `Rules/ExportCodec.swift` — 모델 ↔ DTO 변환, 순수 함수. `ExportDocument: Codable` 구조체가 이 문서의 형식 정의
- `Rules/ExportMigration.swift` — 버전 간 마이그레이션
- 테스트: 고정 샘플 파일 `MasenseTests/Fixtures/export_v1.masense.json`으로 round-trip (내보내기 → 가져오기 → 동일) 검증. `formatVersion`을 올릴 때마다 이전 버전 fixture를 추가하고 마이그레이션 테스트

## 보안·프라이버시

- 파일은 평문. 사용자가 공유 시트로 내보내는 순간부터 사용자 책임임을 내보내기 전 한 줄 안내: "이 파일에는 투약과 건강 기록이 담깁니다. 안전한 곳에 보관하세요."
- 암호화·비밀번호 보호는 v1 범위 밖. 요청이 많으면 v2에서 `.masense.enc` 별도 포맷으로
- 파일에 약물명·상표명 없음 (`doseLabel`은 사용자 입력이므로 예외 — 앱이 생성한 문자열이 아님)

## 버전 이력

| formatVersion | 날짜 | 변경 |
|---|---|---|
| 1 | 2026-10-21 | 초판. SchemaV1 전체 + M2 배열(비어 있을 수 있음) |
