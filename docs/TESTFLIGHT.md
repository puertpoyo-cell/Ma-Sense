# TestFlight — 빌드 절차와 베타 안내문

## 1. 사람이 Mac에서 할 일 (최초 1회)

1. **번들 ID 확정** — 현재 `com.masense.Masense` (테스트 `com.masense.MasenseTests`). Xcode > Masense 타깃 > Signing & Capabilities에서 팀 선택, 필요하면 번들 ID 변경
2. **App Store Connect 앱 생성** — 이름, 기본 언어 한국어, 번들 ID 연결
3. **인앱 구매 상품 생성** — 비소모성 1종. 상품 ID를 정하고 `Masense/Services/StoreService.swift`의 `productID`(현재 `com.masense.pro`)와 맞춘다
4. **HealthKit 사용 여부 결정** — 쓴다면:
   - Signing & Capabilities에 HealthKit 추가 (entitlement)
   - Info.plist 키 `NSHealthShareUsageDescription` = "체중과 운동 기록을 읽어 투약 리포트에 함께 정리합니다." (COMPLIANCE.md 4.2)
   - 이 키가 들어가면 앱의 Health 연동 버튼이 자동으로 보인다 (`HealthKitService.isAvailable`)
5. **개인정보 처리방침 게시** — `docs/privacy/index.html`의 [게시일]·[문의 이메일]을 채우고 게시(GitHub Pages 등). URL을 `Masense/App/AppConfig.swift`의 `privacyPolicyURL`과 App Store Connect에 입력
6. **앱 아이콘** — `Masense/Resources/Assets.xcassets/AppIcon.appiconset`에 1024×1024 (DESIGN_SYSTEM.md 8: Midnight 배경, 가는 선의 마디 하나. 주사기·알약·체중계 금지)

## 2. 빌드 올리기

```bash
# 로컬에서 테스트가 도는지 먼저 확인
xcodebuild -scheme Masense -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Xcode > Product > Archive → Distribute App → App Store Connect → Upload. 업로드 뒤 App Store Connect > TestFlight에서 수출 규정 질문(암호화: 표준 암호화만 사용 → 면제 해당 여부 확인)에 답한다.

## 3. 베타 테스트 정보 (App Store Connect에 붙여 넣을 문구)

### 베타 앱 설명

```
처방은 의사가, 기록은 마선생이.

마선생은 주 1회 주사 치료를 받는 분을 위한 기록 도구입니다. 투약 날짜와 부위, 투약 후 컨디션, 체중을 기록하고 진료 전에 한 장의 리포트로 정리합니다.

마선생은 의학적 조언이나 판단을 하지 않습니다. 처방과 치료 결정은 담당 의사에게 있습니다.
이 앱은 의사의 처방을 받은 만 19세 이상 성인을 위한 기록 도구입니다.
모든 기록은 이 기기에만 저장되며 외부로 전송되지 않습니다.
```

### 테스트해 주실 것

```
1. 처음 실행: 역할·연령 확인 → 처방 입력 → 알림 허용
2. 투약일에 알림을 받고, 투약 기록(부위 선택)을 남겨 주세요
3. 투약 후 24시간·48시간에 컨디션을 기록해 주세요
4. 체중을 직접 입력하거나 Apple 건강 앱과 연동해 주세요
5. 진료 전에 리포트 탭에서 리포트를 만들어 보고, 가능하면 진료 때 보여 주세요

알려 주시면 도움이 되는 것
- 기록을 빠뜨린 순간과 이유
- 리포트를 의사에게 보여 줬는지, 의사가 무엇을 봤는지
- 헷갈린 문구나 화면
```

### 피드백 이메일

[피드백 받을 이메일 입력]

## 4. 베타에서 집계할 것 (PRD 8, 분석 SDK 없음)

- 투약 기록률, 컨디션 체크 응답률: 기기 내 집계를 테스터가 설정 화면에서 확인 (M2 이후 화면 추가 검토)
- 리포트 생성 여부, "의사에게 보여 줬다" 사례: 테스터 설문과 TestFlight 피드백

## 5. 베타 배포 후 규칙

- 베타 빌드가 나간 뒤부터 스키마 변경은 `SchemaMigrationPlan`을 반드시 거친다 (DATA_MODEL.md "스키마 버전")
