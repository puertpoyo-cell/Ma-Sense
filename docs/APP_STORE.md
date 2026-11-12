# App Store 등록 — 설명 초안·스크린샷·심사 준비 (M3)

> 앱 이름은 **마선생**으로 확정했다 (2026-10-22). 홈 화면 표시 이름 `INFOPLIST_KEY_CFBundleDisplayName`과 같다. 부제는 아직 미정이고, App Store Connect에서 이름이 이미 쓰이고 있지 않은지는 앱 생성 때 확인한다.
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
- 진료 기록과 진료 때 물어볼 것 메모
- Apple Watch에서 다음 투약 확인과 기록

마선생은 기록하고 정리할 뿐 판단하지 않습니다. 점수, 랭킹, 칼로리 목표, 목표 체중이 없습니다.
마선생은 의학적 조언이나 진단, 치료를 하지 않습니다. 처방과 치료 결정은 담당 의사에게 있습니다.
의사의 처방을 받은 만 19세 이상 성인을 위한 기록 도구입니다.

기록은 이 기기와 본인 iCloud에만 저장되며 운영자 서버로 전송되지 않습니다. Apple 건강 앱에서 읽은 데이터는 이 기기에만 둡니다. 회원가입이 없고, 분석·광고 도구를 쓰지 않습니다.

기록·알림·컨디션 체크는 모두 무료입니다. 리포트 PDF 내보내기와 리포트 테마는 한 번 구매로 쓸 수 있습니다.
```

### 키워드 (100자 이내, 쉼표 구분, 약물명 금지)

```
투약기록,주사기록,투약알림,주1회,컨디션기록,부작용기록,진료리포트,체중기록,단백질,근력운동
```

### 이번 버전의 새로운 기능 (0.6, 오픈 베타)

```
- 늦거나 일찍 맞은 날 기록에서 "다음부터 이 요일로"를 바로 고를 수 있습니다. 오늘 화면 예정 시간에서 요일·시각도 바꿀 수 있습니다.
- 지난 투약은 오늘 화면과 기록 탭에서 눌러서 바로 고칩니다. 날짜까지 바꿀 수 있습니다.
- 마선생이 진료 일정, 물어볼 것, 반복해서 적은 증상, 남은 펜을 보고 알맞은 때 할 일을 알려 드립니다.
- 건강 앱의 잠을 투약 후 며칠째별로 모아 보는 잠 흐름이 생겼습니다.
- 몸 추이 그래프가 최근 값을 크게, 눈금과 숫자를 함께 보여 줍니다.
- 사진 확인이 반찬 여럿과 포장 글자, 영양성분표까지 봅니다.
- 마선생 말투를 순한맛·매운맛으로 고를 수 있습니다.
```

### 이번 버전의 새로운 기능 (1.0)

```
첫 버전입니다.
```

## 2. 스크린샷

> 초안 자동 촬영: 커밋 메시지에 `[shots]`를 넣거나 Actions에서 "Screenshots"를 수동 실행하면 macOS 러너가 예시 데이터로 화면별 스크린샷을 찍어 아티팩트 `screenshots`로 올린다 (`.github/workflows/screenshots.yml`, DEBUG 실행 인자 `-route`, `ScreenshotRoute`). 스토어용 최종본은 기기 크기별 규격에 맞춰 사람이 고른다

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
- No account, no server, no analytics or ad SDKs. Records the user enters are stored on the device and in the user's private iCloud database (CloudKit) so their own devices stay in sync. The developer cannot access them.
- HealthKit is read-only (body mass, body fat percentage, lean body mass, workouts, sleep) and is used only to show the user's own records and report. HealthKit data stays on the device and is not stored in iCloud. Nothing is written to HealthKit or shared with third parties.
- Apple Watch app: shows the next scheduled day, logs a dose record, and shows a short coach line. It shares records with the iPhone app through the user's private iCloud database only.
- In-app purchase: one non-consumable unlocks report PDF export and report themes. Restore is in Settings > Purchase and on the purchase sheet. Recording, reminders, and condition checks are free.

To try it: complete onboarding (role notice, age confirmation, prescription), then use "투약 기록" on the Today tab, and open Records > Report. Onboarding can be completed without entering a prescription.
```

## 6. 제출 전 체크리스트

- [ ] COMPLIANCE.md 6 출시 전 확인 전부 (상표 검색, 명칭 검토, 가이드라인 재확인, 처리방침 게시, 출처 링크, 베타 안내문, 스크린샷)
- [ ] `python3 scripts/compliance_check.py` 통과 (CI "금지선 점검" 녹색)
- [ ] 인앱 구매 상품 등록·심사 제출 (스크린샷 포함), 상품 ID = `StoreService.productID`
- [x] HealthKit capability와 `NSHealthShareUsageDescription` 추가 (D3-a)
- [ ] 스토어 설명에 HealthKit 사용 명시, 앱 개인정보 보호 항목에 건강·피트니스 데이터(기기 밖으로 수집 안 함) 확인
- [ ] 앱 아이콘 1024×1024 확정 (확정안 "네이비 유리 M" 적용됨, DESIGN_SYSTEM.md 6)
- [ ] 오픈 베타(TESTFLIGHT.md 6) 최소 4주(2026-11-09 사람 결정 "베타 기간을 좀 더 두자"), 치명적 문제 없음, 피드백 반영. 끝나는 날은 피드백을 보고 정함
- [ ] 연령 등급 설문, 앱 개인정보 보호 항목, 심사 메모 입력

## 7. 배포 페이지 채우기 — 다른 채팅방에 붙여 넣는 안내문 (2026-11-12 사람 요청)

App Store Connect 배포 탭(`https://appstoreconnect.apple.com/apps/6826698144/distribution/ios/version/inflight`)을 브라우저에 연결한 채팅방에 그대로 붙여 넣는다. 문구는 위 1·5절과 같게 유지한다. 채우기까지만 하고 심사 제출은 하지 않는다 (오픈 베타 최소 4주 뒤, 2026년 말 목표).

```
App Store Connect에서 iOS 앱 "마선생"의 1.0 버전 배포 페이지를 채우는 일을 도와줘.
페이지: https://appstoreconnect.apple.com/apps/6826698144/distribution/ios/version/inflight

[이 앱]
주 1회 주사 치료를 받는 성인이 투약 날짜·부위, 투약 후 컨디션, 체중을 기록하고 진료 전 리포트 한 장으로 정리하는 iOS 기록 앱. 의학적 조언·판단을 하지 않는다. 지금은 TestFlight 오픈 베타(0.7) 중이고, 정식 출시는 2026년 말 목표다.

[꼭 지킬 것]
1. 채우고 "저장"까지만 한다. "심사에 추가", "심사 제출", 가격 변경, 앱 삭제, 빌드 제거는 누르지 않는다. 필요해 보이면 멈추고 나에게 묻는다.
2. 어떤 칸에도 의약품 상표명, 약 이름, 용량 수치, 효과·감량 약속을 넣지 않는다. 느낌표와 이모지도 넣지 않는다.
3. 아래에 없는 값(지원 URL, 저작권, 연락처 이름·전화·이메일, 카테고리, 가격)은 지어내지 말고 나에게 묻는다.
4. 칸을 하나 채울 때마다 무엇을 넣었는지 한 줄로 알려 주고, 글자 수 제한에 걸리면 줄이지 말고 나에게 보여 준다.
5. 로그인·2단계 인증·결제 화면이 나오면 멈추고 내가 직접 한다.

[먼저 할 일]
페이지를 읽고, 지금 비어 있는 칸과 이미 채워진 칸을 표로 정리해 보여 줘. 그다음 아래 값으로 빈칸을 채운다. 이미 채워진 값이 아래와 다르면 바꾸기 전에 묻는다.

[프로모션 텍스트]
처방은 의사가, 기록은 마선생이. 투약 날짜와 부위, 투약 후 컨디션, 체중을 담담하게 기록하고 진료 전에 한 장의 리포트로 정리합니다.

[설명]
처방은 의사가, 기록은 마선생이.

주 1회 주사 치료를 받고 계신가요? 마선생은 투약 날짜와 부위, 투약 후 컨디션, 체중을 담담하게 기록하고, 진료 전 한 장의 리포트로 정리합니다.

- 투약 알림과 다음 투약까지 카운트다운
- 주사 부위 기록 (최근 사용 부위와 날짜 표시)
- 투약 후 24·48시간 컨디션 체크
- Apple 건강 앱 체중 연동 또는 직접 입력
- 단백질과 근력운동 기록으로 감량 중 생활 습관 확인
- 진료 전 리포트 PDF (A4 한 장)
- 진료 기록과 진료 때 물어볼 것 메모
- Apple Watch에서 다음 투약 확인과 기록

마선생은 기록하고 정리할 뿐 판단하지 않습니다. 점수, 랭킹, 칼로리 목표, 목표 체중이 없습니다.
마선생은 의학적 조언이나 진단, 치료를 하지 않습니다. 처방과 치료 결정은 담당 의사에게 있습니다.
의사의 처방을 받은 만 19세 이상 성인을 위한 기록 도구입니다.

기록은 이 기기와 본인 iCloud에만 저장되며 운영자 서버로 전송되지 않습니다. Apple 건강 앱에서 읽은 데이터는 이 기기에만 둡니다. 회원가입이 없고, 분석·광고 도구를 쓰지 않습니다.

기록·알림·컨디션 체크는 모두 무료입니다. 리포트 PDF 내보내기와 리포트 테마는 한 번 구매로 쓸 수 있습니다.

[키워드]
투약기록,주사기록,투약알림,주1회,컨디션기록,부작용기록,진료리포트,체중기록,단백질,근력운동

[이번 버전의 새로운 기능] (칸이 보이면)
첫 버전입니다.

[개인정보 처리방침 URL] (앱 정보 또는 앱이 수집하는 개인정보 페이지)
https://masense-privacy.vercel.app/

[앱 심사 정보]
- 로그인 필요: 아니요 (계정이 없는 앱)
- 연락처 이름·전화·이메일: 나에게 묻기
- 메모:
This app is a personal record-keeping tool for adults with a doctor's prescription for a once-weekly injection. It records dose dates, injection sites, post-dose symptoms, and weight, and summarizes them in a one-page PDF to show the doctor.

- It gives no medical advice, diagnosis, dosage recommendation, or treatment suggestions. All health guidance ends with "consult your doctor".
- No account, no server, no analytics or ad SDKs. Records the user enters are stored on the device and in the user's private iCloud database (CloudKit) so their own devices stay in sync. The developer cannot access them.
- HealthKit is read-only (body mass, body fat percentage, lean body mass, workouts, sleep) and is used only to show the user's own records and report. HealthKit data stays on the device and is not stored in iCloud. Nothing is written to HealthKit or shared with third parties.
- Apple Watch app: shows the next scheduled day, logs a dose record, and shows a short coach line. It shares records with the iPhone app through the user's private iCloud database only.
- In-app purchase: one non-consumable unlocks report PDF export and report themes. Restore is in Settings > Purchase and on the purchase sheet. Recording, reminders, and condition checks are free.

To try it: complete onboarding (role notice, age confirmation, prescription), then use "투약 기록" on the Today tab, and open Records > Report. Onboarding can be completed without entering a prescription.

[버전 출시]
"수동으로 이 버전 출시"를 고른다.

[지금은 채우지 않고 남겨 둘 것 — 건드리지 말고 목록으로만 알려 줘]
- 스크린샷·앱 미리보기: 아직 새로 찍는 중
- 빌드 선택: 출시 후보 빌드가 정해지면 내가 고른다
- 인앱 구매(상품 ID com.masense.pro, 비소모성 1종): 아직 등록 전. 등록 화면이 필요하면 어디서 하는지만 알려 줘
- 부제: 후보는 "주 1회 투약 기록과 진료 전 리포트"이지만 확정 전이라 넣기 전에 묻는다
- 연령 등급 설문, 앱이 수집하는 개인정보("데이터를 수집하지 않음"으로 답할 예정), 카테고리, 가격: 해당 화면으로 가기 전에 나에게 확인

[끝나면]
채운 칸, 남은 칸, 내가 정해 줘야 할 것을 표로 정리해 줘. 심사 제출 버튼은 누르지 않는다.
```
