# App Store 등록 — 설명 초안·스크린샷·심사 준비 (M3)

> 앱 이름·부제·브랜딩은 별도 논의 후 확정한다. 아래 문구의 "마선생"은 현재 작업명이다.
> 모든 문구는 COMPLIANCE.md 4.3·4.5를 따른다: 특정 약물명·용량·효과 약속 없음, 의학적 조언 없음을 명시.

## 1. 스토어 문구 초안

### 부제 (30자 이내, 확정 전)

```
주 1회 투약 기록과 진료 전 리포트
```

### 프로모션 텍스트 (170자 이내)

```
처방은 의사가, 기록은 마선생이. 투약 날짜와 부위, 투약 후 컨디션, 체중을 담담하게 기록하고 진료 전에 한 장의 리포트로 정리합니다.
```

### 설명

```
처방은 의사가, 기록은 마선생이.

주 1회 주사 치료를 받고 계신가요? 마선생은 투약 날짜와 부위, 투약 후 컨디션, 체중을 담담하게 기록하고, 진료 전 한 장의 리포트로 정리합니다.

- 투약 알림과 다음 투약까지 카운트다운
- 주사 부위 기록 (최근 사용 부위와 날짜 표시)
- 투약 후 24·48시간 컨디션 체크
- Apple 건강 앱 체중 연동 또는 직접 입력
- 단백질과 근력운동 기록으로 감량 중 생활 습관 확인
- 진료 전 리포트 PDF (A4 한 장)

마선생은 기록하고 정리할 뿐 판단하지 않습니다. 점수, 랭킹, 칼로리 목표, 목표 체중이 없습니다.
마선생은 의학적 조언이나 진단, 치료를 하지 않습니다. 처방과 치료 결정은 담당 의사에게 있습니다.
의사의 처방을 받은 만 19세 이상 성인을 위한 기록 도구입니다.

모든 기록은 이 기기에만 저장되며 외부로 전송되지 않습니다. 회원가입이 없고, 분석·광고 도구를 쓰지 않습니다.

기록·알림·컨디션 체크는 모두 무료입니다. 리포트 PDF 내보내기와 리포트 테마는 한 번 구매로 쓸 수 있습니다.
```

### 키워드 (100자 이내, 쉼표 구분, 약물명 금지)

```
투약기록,주사기록,투약알림,주1회,컨디션기록,부작용기록,진료리포트,체중기록,단백질,근력운동
```

### 이번 버전의 새로운 기능 (1.0)

```
첫 버전입니다.
```

## 2. 스크린샷

예시 데이터로 찍는다: Xcode > Product > Scheme > Edit Scheme > Run > Arguments에 `-seedSampleData`를 넣고, **앱을 지운 뒤** 시뮬레이터에서 실행한다 (빈 저장소일 때만 채운다). 예시 데이터에는 약물명·용량 수치·메모가 없다 (`Masense/App/SampleData.swift`).

| 순서 | 화면 | 보여 줄 것 | 캡션 초안 |
|---|---|---|---|
| 1 | 오늘 | 카운트다운(D-1), 체중 카드, 오늘의 마디, 진료 카드 | 다음 투약까지, 한눈에 |
| 2 | 투약 기록 | 바디맵(최근 부위 날짜), 회차 | 어느 부위에 맞았는지 기록 |
| 3 | 컨디션 체크 | 증상 칩과 강도 | 투약 후 24·48시간 컨디션 |
| 4 | 기록 탭 | 투약 목록(누락 마디 점선) | 빠진 기록도 나중에 채우기 |
| 5 | 리포트 | A4 미리보기 | 진료 전 리포트 한 장 |
| 6 | 단백질 기록 | 끼니·식품 칩 | 단백질과 근력운동도 함께 |

확인할 것 (COMPLIANCE.md 6):
- [ ] 약물명·상표·용량 수치가 화면에 없다 (처방 메모는 비워 둔다)
- [ ] 캡션에 효과 약속·감량 수치 강조가 없다
- [ ] 다크 모드(앱 고정) 상태로 찍는다

## 3. 앱 개인정보 보호 (App Store Connect "App Privacy")

- 데이터 수집: **수집하지 않음 (Data Not Collected)**. 서버·분석·광고 SDK 없음
- 개인정보 처리방침 URL: `docs/privacy/index.html` 게시 후 입력 (`AppConfig.privacyPolicyURL`과 같게)

## 4. 연령 등급

- 설문에서 의료/치료 정보 항목은 COMPLIANCE.md 4.1 방향(드문/경미한 의료/치료 정보)으로 답하고, 최종 등급은 App Store Connect 설문 결과를 따른다
- 앱 자체 고지: 온보딩에서 "의사의 처방을 받은 만 19세 이상 성인" 확인

## 5. 심사 메모 (App Review Information > Notes)

```
This app is a personal record-keeping tool for adults with a doctor's prescription for a once-weekly injection. It records dose dates, injection sites, post-dose symptoms, and weight, and summarizes them in a one-page PDF to show the doctor.

- It gives no medical advice, diagnosis, dosage recommendation, or treatment suggestions. All health guidance ends with "consult your doctor".
- All data stays on the device (SwiftData). No account, no server, no analytics or ad SDKs.
- HealthKit is read-only (body mass, lean body mass, workouts) and is used only to show the user's own records and report. Nothing is written to HealthKit or shared with third parties.
- In-app purchase: one non-consumable unlocks report PDF export and report themes. Restore is in Settings > Purchase and on the purchase sheet. Recording, reminders, and condition checks are free.

To try it: complete onboarding (role notice, age confirmation, prescription), then use "투약 기록" on the Today tab, and open the Report tab.
```

## 6. 제출 전 체크리스트

- [ ] COMPLIANCE.md 6 출시 전 확인 전부 (상표 검색, 명칭 검토, 가이드라인 재확인, 처리방침 게시, 출처 링크, 베타 안내문, 스크린샷)
- [ ] `python3 scripts/compliance_check.py` 통과 (CI "금지선 점검" 녹색)
- [ ] 인앱 구매 상품 등록·심사 제출 (스크린샷 포함), 상품 ID = `StoreService.productID`
- [ ] HealthKit을 쓰면 capability와 `NSHealthShareUsageDescription` 추가, 스토어 설명에 HealthKit 사용 명시
- [ ] 앱 아이콘 1024×1024 (DESIGN_SYSTEM.md 8)
- [ ] TestFlight 2차까지 치명적 문제 없음
- [ ] 연령 등급 설문, 앱 개인정보 보호 항목, 심사 메모 입력
