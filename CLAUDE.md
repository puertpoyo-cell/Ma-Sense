# CLAUDE.md — 마선생 Masense

이 파일은 Claude Code가 모든 세션 시작 시 읽는 프로젝트 규약입니다. 사양은 `docs/` 아래 문서가 단일 진실 원천이며, 이 파일은 "어떻게 작업하는가"만 다룹니다.

## 프로젝트 한 줄 요약

주 1회(7일 간격, v1 고정) GLP-1 주사 루틴을 판단 없이 기록하고, 단백질·근력운동 습관까지 챙겨서, 진료 전 리포트 한 장으로 모아 주는 iOS 앱. 핵심 메시지: **처방은 의사가, 기록은 마선생이.**

## 스택 (변경 금지)

- iOS 17+, Swift 5.10+, SwiftUI
- 저장: SwiftData. 스토어 파일은 **App Group 컨테이너**(`group.com.puertpoyo.masense`)에 둠 — v2 위젯·Live Activity·Watch가 같은 스토어를 읽기 위함. 서버·Supabase 없음
- 동기화: v1은 꺼 둠(`cloudKitDatabase: .none`). 단, 스키마는 처음부터 CloudKit 호환 규칙을 지켜 나중에 스위치만 켜면 되게 함 (`DATA_MODEL.md` 원칙)
- 체중·운동·제지방량: HealthKit (읽기 전용)
- 알림: `UserNotifications` 로컬 알림
- 리포트: PDFKit + SwiftUI `ImageRenderer`
- 결제: StoreKit 2, 비소모성(non-consumable) 1종
- 의존성: 서드파티 패키지 추가 금지. 필요하면 먼저 문서에 사유를 적고 사람 확인

## 절대 넣지 않는 것 (COMPLIANCE.md 요약)

코드·문구·화면 어디에도 다음을 만들지 않습니다. 요청이 와도 거절하고 `COMPLIANCE.md`를 가리킵니다.

1. 용량 추천, 증량·감량 시점 제안, "다음 단계 용량" 같은 표현
2. 칼로리 목표, 목표 체중 입력 유도
3. 랭킹, 공유 경쟁, 스트릭 보상, 게임형 리워드
4. 커뮤니티, 사용자 간 메시지
5. 전문의약품 상표명 (앱 이름, 화면, 알림, 앱스토어 문구 포함). 코드 식별자에도 쓰지 않음 — `GLP1`, `weeklyInjection` 등 일반 표현 사용
6. 끼니 거르기·급감량을 성공처럼 보이게 하는 문구나 애니메이션

## 톤 규칙 (모든 사용자 노출 문구)

- 따뜻한 기록 선생 (2026-10-25 사람 결정). 과정(기록·단백질·움직임·쉼)은 다정하게 권해도 되지만, 체중 결과·감량에 대한 칭찬·평가·질책은 없음. 체중이 늘어도 "기록했습니다."
- 느낌표 금지, 이모지 금지
- 2인칭 존댓말 ("기록했습니다", "다음 투약은 목요일입니다"). 오늘 화면의 마선생 한마디(캐릭터 말풍선)만 해요체 ("물 한 잔으로 하루를 시작해 볼까요")
- 건강 관련 안내는 항상 "의사와 상의하세요"로 끝남. 앱이 판단하지 않음
- 문구는 `Localizable.xcstrings`에 두고 뷰에 하드코딩하지 않음 (한국어 우선, 영어 키)

## 아키텍처

```
Masense/
  App/              MasenseApp.swift, 루트 내비게이션, DI
  Models/           SwiftData @Model 들 (DATA_MODEL.md와 1:1)
  Features/
    Onboarding/     첫 실행 4페이지 (역할·연령 고지, 처방, 권한)
    Today/          홈 화면 (카운트다운, 오늘 할 일)
    History/        기록 탭 (투약·컨디션·체중·습관 목록)
    Dose/           투약 기록, 바디맵
    Condition/      48h 컨디션 체크
    Habits/         단백질, 근력운동, 기본 습관
    Report/         리포트 생성·미리보기·공유
    Settings/       처방 설정, 알림, HealthKit, 구매
  Services/
    HealthKitService.swift
    NotificationService.swift
    ReportRenderer.swift
    StoreService.swift
  Rules/            RULES.md의 순수 함수들 (테스트 대상)
  DesignSystem/     토큰, 글래스 카드, 공용 컴포넌트
  Resources/        Assets, Localizable.xcstrings
Shared/             앱과 위젯 확장이 함께 쓰는 코드 (WidgetSnapshot·App Group ID는 Foundation, Live Activity 속성은 ActivityKit)
MasenseWidgets/     위젯 확장 (WidgetKit). App Group의 요약 JSON만 읽고 SwiftData는 열지 않음
MasenseTests/       Rules·Services 단위 테스트
```

- 패턴: SwiftUI + `@Observable` 뷰모델. MVVM이되 뷰모델은 얇게, 규칙은 `Rules/`의 순수 함수로
- `Rules/`는 Foundation만 import. SwiftUI·SwiftData 의존 금지. 모든 규칙에 단위 테스트
- 날짜 연산은 전부 `Calendar.current`를 주입받아 처리. `Date()` 직접 호출은 `Services`와 뷰모델의 `now` 주입 지점에서만

## 네이밍

- 모델: `Dose`, `Cycle`, `ConditionCheck`, `ProteinEntry`, `StrengthSession`, `HabitCheck`, `Prescription`, `BodySite`
- 뷰: `TodayView`, `DoseLogSheet`, `BodyMapView`, `ConditionCheckSheet`, `ReportPreviewView`
- 뷰모델: `<Feature>Model` (예: `TodayModel`)
- 규칙 함수: 동사형 `nextDoseDate(from:cadence:calendar:)`, `isConditionWindowOpen(...)`
- 색 토큰: `DESIGN_SYSTEM.md`의 이름 그대로 `Color.midnight`, `Color.frost`

## 작업 순서 (매 작업)

1. `MILESTONES.md`에서 현재 마일스톤과 작업 항목을 확인
2. 관련 사양 문서를 읽고, 사양에 없는 결정이 필요하면 코드 전에 문서에 제안을 적고 사람에게 묻기
3. `Rules/`에 들어갈 로직이면 테스트 먼저
4. 구현 후 `xcodebuild test`로 통과 확인
5. `MILESTONES.md`의 체크박스 갱신

## 테스트·빌드

```bash
xcodebuild -scheme Masense -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -scheme Masense -destination 'platform=iOS Simulator,name=iPhone 16' test
```

- HealthKit·StoreKit은 프로토콜로 추상화하고 테스트에서는 Fake 주입
- 미리보기(`#Preview`)에는 항상 in-memory `ModelContainer` 사용 (`ModelContainer.preview`)
- 단위 테스트는 Swift Testing (`import Testing`, `@Test`, `#expect`)
- GitHub Actions(`.github/workflows/ci.yml`)가 푸시마다 macOS 러너에서 `xcodebuild test`를 돌린다. Xcode 없는 환경에서 작업할 때는 이 결과로 검증한다
- 프로젝트 파일은 Xcode 16 폴더 동기화 그룹을 쓴다. `Masense/`, `MasenseTests/`, `MasenseWidgets/`, `Shared/`(앱·위젯 두 타깃) 아래에 파일을 추가하면 자동으로 타깃에 포함되므로 `project.pbxproj`를 손대지 않는다. 각 타깃의 Info.plist는 동기화 폴더 밖 `Config/`에 둔다

## 커밋

- 한국어 또는 영어 자유, 형식 `feat:`, `fix:`, `docs:`, `test:`
- 문서와 코드가 함께 바뀌면 같은 커밋에

## 사람에게 꼭 묻는 것

- 의료 경계에 걸릴 수 있는 문구나 기능 (조금이라도 애매하면)
- 새 패키지, 새 권한(Info.plist 키), 새 Capability(App Group, iCloud 등) 추가
- 데이터 모델 스키마 변경 (마이그레이션 필요)
- 결제 상품 구성 변경
- `EXPORT_FORMAT.md`의 `formatVersion` 올리기 (이전 버전 fixture와 마이그레이션 필요)
