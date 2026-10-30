# TestFlight — 빌드 절차와 베타 안내문

## 1. 사람이 Mac에서 할 일 (최초 1회)

1. **번들 ID** — `com.masense.app`로 확정(2026-10-22, 테스트 `com.masense.app.tests`). Xcode > Masense 타깃 > Signing & Capabilities에서 팀만 선택한다
2. **App Store Connect 앱 생성** — 이름, 기본 언어 한국어, 번들 ID 연결
3. **인앱 구매 상품 생성** — 비소모성 1종, 상품 ID `com.masense.pro` (2026-10-22 확정, `StoreService.productID`). 만든 뒤 Xcode에서 동기화 `.storekit` 구성 파일을 만들어 스킴에 지정하면 시뮬레이터에서 구매·복원을 시험할 수 있다
4. **HealthKit** — 사용하기로 결정(2026-10-22), 코드에 반영됨:
   - entitlement `Config/Masense.entitlements` (`CODE_SIGN_ENTITLEMENTS`), 사용 설명 `INFOPLIST_KEY_NSHealthShareUsageDescription` + 번역 `Masense/Resources/InfoPlist.xcstrings` (COMPLIANCE.md 4.2)
   - 1번에서 팀을 고르면 자동 서명이 App ID에 HealthKit을 등록한다. Signing & Capabilities에 HealthKit이 보이는지만 확인
   - 실기기에서 온보딩 4페이지 또는 설정 > 연동의 버튼으로 권한 화면이 뜨는지 확인
5. **개인정보 처리방침 게시 (Vercel, 2026-10-22 결정)** — `docs/privacy/index.html`의 [게시일]·[문의 이메일]을 채운 뒤:
   1. vercel.com > Add New > Project > GitHub 저장소 `puertpoyo-cell/Ma-Sense` 가져오기
   2. Framework Preset **Other**, Root Directory **`docs/privacy`**, Build·Output 설정은 비워 둔다 (빌드 없는 HTML 한 장)
   3. 프로덕션 배포는 기본 브랜치(main)에서 나간다. 작업 브랜치를 main에 머지하거나, Settings > Git > Production Branch를 작업 브랜치로 바꾼다
   4. `docs/privacy/vercel.json`: 확장자 없는 주소(`cleanUrls`), 처리방침 폴더가 바뀐 커밋만 배포(`ignoreCommand`)
   5. 다시 배포할 때(처리방침 문구가 바뀐 뒤): Mac에서 `cd ~/Developer/Ma-Sense/docs/privacy && npx vercel --prod`, 프로젝트는 `masense-privacy` 선택 (2026-10-27 확인). 클라우드 세션은 Vercel에 접속할 수 없어 사람이 한다
   5. 배포 주소(`https://<프로젝트 이름>.vercel.app`)를 `Masense/App/AppConfig.swift`의 `privacyPolicyURL`과 App Store Connect에 입력. 넣으면 설정 > 정보에 처리방침 링크가 보인다
6. **앱 아이콘** — 확정안 "네이비 유리 M"(다크 네이비 바탕, 1차안 볼륨 × 1.28배)이 `AppIcon.appiconset/AppIcon.png`에 들어가 있다 (`python3 scripts/make_app_icon.py`로 다시 생성, DESIGN_SYSTEM.md 6). 앱 이름은 "마선생"으로 확정 (2026-10-22)

## 2. 빌드 올리기

```bash
# 로컬에서 테스트가 도는지 먼저 확인
xcodebuild -scheme Masense -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Xcode > 실행 대상 "Any iOS Device (arm64)" > Product > Archive → Distribute App → App Store Connect → Upload.

- 수출 규정: `Config/Masense-Info.plist`에 `ITSAppUsesNonExemptEncryption = NO` (2026-10-25). 앱이 자체 암호화를 쓰지 않고 OS의 HTTPS·StoreKit만 쓰므로 면제. 업로드마다 질문이 뜨지 않는다
- 개인정보 매니페스트: `Masense/Resources/PrivacyInfo.xcprivacy` (2026-10-25). 추적 없음, 수집 데이터 없음(기록은 기기에만), 필수 사유 API는 `@AppStorage`의 UserDefaults(CA92.1, 앱 자신만 읽고 씀). 위젯 확장은 사유 API를 쓰지 않음. 새 사유 API를 쓰면 여기에 추가한다
- HealthKit 쓰기 문구: 앱은 쓰기 권한을 요청하지 않지만(`toShare: []`), HealthKit entitlement가 있으면 업로드 검사가 `NSHealthUpdateUsageDescription`을 요구해 거절한다 (2026-10-25 업로드 실패). "쓰지 않는다"는 사실만 적은 문구를 `INFOPLIST_KEY_NSHealthUpdateUsageDescription` + `InfoPlist.xcstrings`에 둔다
- 빌드 번호는 앱 코드가 바뀐 PR을 main에 합칠 때마다 Claude가 1씩 올린다 (2026-10-27 사람 결정, CLAUDE.md 커밋). 사람이 손으로 올릴 필요 없다.
- 다시 올릴 때는 `CURRENT_PROJECT_VERSION`(빌드 번호)을 앱·위젯 두 타깃에서 함께 올린다. 같은 `MARKETING_VERSION` 안에서 빌드 번호가 겹치면 업로드가 거절된다
- 2026-10-25 확인: `xcodebuild -scheme Masense -configuration Release -destination 'generic/platform=iOS' archive` 성공 (0.2 (1), HealthKit·App Group entitlement 포함, 위젯 확장 내장)

### 실기기에서 화면 좌우에 검은 띠가 보이면

앱이 기기의 화면 크기를 모르는 오래된 SDK로 빌드되어 호환 모드로 도는 경우다. 앱 설정(Info.plist)으로는 끌 수 없고, 기기의 iOS와 같은 세대의 Xcode로 다시 빌드하면 사라진다 ([Apple 개발자 포럼 DTS 답변](https://developer.apple.com/forums/thread/847856)).
- 기기: 설정 > 일반 > 정보 > iOS 버전, Mac: Xcode > About Xcode 버전을 비교한다 (예: iOS 27 기기면 Xcode 27)
- 2026-10-23 확인: Xcode 26.3 + iOS 26 시뮬레이터(iPhone 17 Pro)에서는 띠 없이 화면을 다 채운다. CI 스크린샷 워크플로를 수동 실행하며 `xcode` 입력(예: `26`)을 주면 그 Xcode로 찍어 볼 수 있다

## 2-1. 자동 업로드 (N-A, 2026-10-29 사람 승인) — `.github/workflows/testflight.yml`

main에 앱 코드(`Masense/`, `Shared/`, `MasenseWidgets/`, `Config/`, `project.pbxproj`)가 바뀌어 올라가면 GitHub Actions가 Release Archive를 만들어 App Store Connect에 올린다. 처리가 끝나면(보통 5~15분) 폰의 TestFlight 앱에서 업데이트만 누르면 된다. Mac·Xcode·pull이 필요 없다.
서명은 Xcode 클라우드 관리 서명이라 **App Store Connect API 키 하나**만 있으면 된다 (.p12 인증서·프로비저닝 프로파일 불필요). 공개 저장소라 Actions 시간은 무료.

### 사람이 한 번 할 일 (Secrets 3개)

1. **API 키 만들기**: [App Store Connect](https://appstoreconnect.apple.com) > 사용자 및 액세스 > **통합** 탭 > App Store Connect API > 팀 키 **+**
   - 이름 `masense-ci`, 액세스 **App Manager** (업로드에 필요한 최소 권한은 Developer이지만 클라우드 서명이 인증서를 만들려면 App Manager)
   - 만들면 **Issuer ID**(페이지 위), **키 ID**, 그리고 `.p8` 파일 다운로드 (한 번만 받을 수 있다. 잃으면 키를 새로 만든다)
2. **GitHub Secrets 등록**: github.com/puertpoyo-cell/Ma-Sense > Settings > Secrets and variables > Actions > **New repository secret** 세 번
   - `ASC_KEY_ID` — 키 ID (예: `AB12CD34EF`)
   - `ASC_ISSUER_ID` — Issuer ID (UUID 모양)
   - `ASC_PRIVATE_KEY` — `.p8` 파일을 텍스트 편집기로 열어 `-----BEGIN PRIVATE KEY-----`부터 `-----END PRIVATE KEY-----`까지 **전체를 그대로** 붙여 넣기
3. **첫 실행**: Actions 탭 > TestFlight > Run workflow (main). 첫 번째는 클라우드 서명이 배포 인증서를 새로 만들므로 1~2분 더 걸린다
   - 워크플로는 GitHub `xcode-27` 러너(공개 미리보기)의 Xcode 27.1로 빌드한다 (D23: iPhone Duo 펼친 화면을 다 쓰려면 iOS 27.1 SDK. App Store Connect는 iOS 26 SDK 이상만 받음, 2026-10-30 확인). Secret의 키가 한 줄로 붙어 있어도 PEM을 다시 만들어 쓴다
   - 실패하면 로그의 `error:` 줄을 Claude에게 보내면 된다. 흔한 원인: 키 권한이 Developer(→ App Manager로), Secrets 이름 오타, 같은 빌드 번호 재업로드
4. 그 뒤로는 main에 앱 코드가 올라갈 때마다 자동. 문서만 바뀐 커밋은 돌지 않는다. Secrets가 없으면 "Secrets 확인" 단계에서 조용히 끝난다

### 수동 업로드가 여전히 필요한 때
- 처음 App Store 심사 제출(스크린샷·설명 입력)은 App Store Connect 웹에서 사람이 한다. 빌드 자체는 자동 업로드된 것을 고르면 된다
- 클라우드 서명이 만든 인증서는 App Store Connect > 인증서에서 보인다. Mac의 Xcode 수동 Archive도 그대로 된다

## 7. iCloud 동기화 켜기 (N-I1, v2 — 사람이 할 일)

스키마는 처음부터 CloudKit 호환 규칙(DATA_MODEL.md)을 지켰고, 코드는 `AppConfig.iCloudSyncEnabled` 하나로 켠다. 순서대로:
1. Xcode > Masense 타깃 > Signing & Capabilities > **+ Capability** > **iCloud** → Services에서 **CloudKit** 체크 → Containers **+** → `iCloud.com.puertpoyo.masense`
2. 같은 화면에서 **+ Capability** > **Background Modes** → **Remote notifications** 체크 (CloudKit이 변경을 밀어 주는 데 필요)
3. `Config/Masense.entitlements`에 `com.apple.developer.icloud-container-identifiers`·`com.apple.developer.icloud-services`·`aps-environment`가 생겼는지 확인하고 커밋 (Xcode가 자동으로 넣는다)
4. `AppConfig.iCloudSyncEnabled = true`로 바꾼다 (Claude에게 "iCloud 켜 줘"라고 하면 이 줄과 처리방침 문구를 함께 바꾼다)
5. 처리방침 2장·3장 "iCloud 동기화도 하지 않습니다"를 "사용자의 개인 iCloud에 백업됩니다"로 고치고 Vercel 재배포 (2-1 절차)
6. 실기기 두 대에서 같은 Apple ID로 기록이 오가는지 확인. 첫 동기화는 몇 분 걸린다
- 켜기 전 조건: 저장 속성에 `@Attribute(.unique)` 없음(SchemaTests), 관계 전부 옵셔널 또는 기본값, 삭제 규칙 `.deny` 없음 — 모두 지켜져 있다
- 켜지 않고 `iCloudSyncEnabled = true`만 두면 앱이 시작할 때 컨테이너를 못 열어 죽는다

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
