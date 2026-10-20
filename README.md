# 마선생 Masense

처방은 의사가, 기록은 마선생이.

주 1회 투약 루틴을 판단 없이 기록하고, 단백질·근력운동 습관까지 챙겨서, 진료 전 리포트 한 장으로 모아 주는 iOS 앱.

## 문서

사양은 `docs/`가 단일 진실 원천입니다. 작업 규약은 `CLAUDE.md`를 봅니다.

- `docs/PRD.md` 제품 요구사항
- `docs/DATA_MODEL.md` SwiftData 스키마
- `docs/SCREENS.md` 화면 사양
- `docs/RULES.md` 비즈니스 규칙
- `docs/REPORT_SPEC.md` 진료 전 리포트
- `docs/DESIGN_SYSTEM.md` 디자인 토큰
- `docs/COMPLIANCE.md` 의료 경계·문구·심사
- `docs/MILESTONES.md` 빌드 순서와 진행 상황

## 스택

iOS 17+, Swift 5.10+, SwiftUI, SwiftData(온디바이스 전용). 서드파티 패키지 없음.

## 빌드·테스트

Xcode 16 이상에서 `Masense.xcodeproj`를 엽니다.

```bash
xcodebuild -scheme Masense -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -scheme Masense -destination 'platform=iOS Simulator,name=iPhone 16' test
```

GitHub Actions(`.github/workflows/ci.yml`)가 푸시마다 macOS 러너에서 같은 테스트를 돌립니다.
