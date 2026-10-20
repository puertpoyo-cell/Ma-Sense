# DESIGN_SYSTEM — Midnight / Frost

Deep Midnight Navy 배경 위에 Frosted Glass 카드. 건축 도면처럼 정렬된 그리드. 토큰 이름은 코드와 동일하게 씁니다 (`Masense/DesignSystem/`).

## 1. 색 토큰

| 토큰 | Light(앱은 다크 고정) | 용도 |
|---|---|---|
| `midnight` | `#0B1220` | 앱 배경 |
| `midnightElevated` | `#111B2E` | 시트 배경 |
| `frost` | `white.opacity(0.08)` + `.ultraThinMaterial` | 카드 채움 |
| `frostBorder` | `white.opacity(0.14)` | 카드 1px 테두리 |
| `ink` | `#F2F5FA` | 본문 텍스트 |
| `inkSecondary` | `#9AA7BD` | 보조 텍스트 |
| `inkTertiary` | `#5E6B82` | 비활성, 격자선 |
| `accent` | `#7FB3FF` | 버튼, 선택 상태, 라인 차트 |
| `accentSoft` | `accent.opacity(0.18)` | 선택 배경 |
| `siteRecent` | `accent` 농도 4단계 (1.0 / 0.7 / 0.45 / 0.25) | 바디맵 최근 사용 |
| `notice` | `#E8D9A8` | 안내 문구 (경고 아님, 따뜻한 중립) |

- 앱은 다크 모드 고정 (`preferredColorScheme(.dark)`). 라이트 토큰은 리포트 PDF에서만 사용 (흰 배경, `ink` → `#111827`)
- **빨강·초록 금지.** 상태를 색으로 판단하지 않는다는 원칙의 시각적 표현. 심각도 3도 굵기와 텍스트로만
- 테마 구매는 `accent` 하나만 교체: `midnight`(기본 `#7FB3FF`), `sand`(`#E8C9A0`), `sage`(`#A8D5BA`)

## 2. 타이포그래피

시스템 폰트(SF Pro / Apple SD Gothic Neo), Dynamic Type 대응. 숫자는 `.monospacedDigit()`.

| 토큰 | 스타일 | 용도 |
|---|---|---|
| `display` | 56pt, `.bold`, rounded | 카운트다운 "D-3" |
| `title` | `.title2`, `.semibold` | 카드 제목 |
| `body` | `.body` | 본문 |
| `label` | `.subheadline`, `.medium` | 칩, 버튼 |
| `caption` | `.caption`, `inkSecondary` | 날짜, 보조 |
| `mono` | `.body.monospaced()` | 회차 "3 / 12" |

줄 간격 여유: 본문 `lineSpacing(4)`. 느낌표·이모지 없음은 톤 규칙이지만 타이포에서도 지킴.

## 3. 간격·격자

- 기본 단위 4pt. 토큰: `s1=4, s2=8, s3=12, s4=16, s5=24, s6=32, s7=48`
- 화면 좌우 여백 `s5`(24). 카드 간 `s4`(16). 카드 내부 패딩 `s5`
- 카드 모서리 `20`, 칩 모서리 `10`, 버튼 모서리 `14`
- 격자 정렬: 카드 내부 요소는 2컬럼 또는 4컬럼 그리드에 맞춤. 숫자는 우측 정렬, 라벨은 좌측 정렬 (도면 치수 표기처럼)

## 4. 글래스 카드

```swift
struct FrostCard<Content: View>: View {
    var body: some View {
        content
            .padding(Spacing.s5)
            .background(.ultraThinMaterial)
            .background(Color.white.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.frostBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
```

- 그림자 없음. 깊이는 테두리와 재질로만
- 배경에 아주 옅은 방사형 그라데이션 1개 (`accent.opacity(0.06)` 상단 좌측) — 과하지 않게
- 카드 안에 카드 중첩 금지. 섹션 구분은 `inkTertiary` 1px 선

## 5. 컴포넌트

| 이름 | 설명 |
|---|---|
| `FrostCard` | 위 |
| `CountdownHero` | display 숫자 + caption. 상태 4종 (R2) |
| `BodyMapView` | 정면 실루엣 SVG → `Path`. 8구역 `Shape`, 선택·최근 농도. 실루엣은 중성적 아웃라인, 성별 표현 없음 |
| `SymptomChip` | 라벨 + 0~3 세그먼트. 선택 시 `accentSoft` 배경 |
| `MealSlotRow` | 끼니 4칸, 채움은 `accent` 점 |
| `WeekSparkline` | 주 평균 라인, nil 끊김, 투약일 눈금. 축 라벨 없음 (홈용) |
| `WeekChart` | Swift Charts, 축 포함 (기록 탭·리포트용) |
| `NoticeLine` | `notice` 색 텍스트 한 줄 + 아이콘 `info.circle`. 경고 아이콘 금지 |
| `PrimaryButton` | `accent` 채움, `midnight` 텍스트, 높이 52 |
| `GhostButton` | 테두리만 |
| `RecordedToast` | "기록했습니다." 1.2초, 하단 |

## 6. 모션

- 카드 등장 `opacity + offset(y: 8)` 0.25s easeOut. 스프링 과장 없음
- 기록 완료 시 축하 애니메이션 없음. 토스트만
- 카운트다운 숫자 변경 `contentTransition(.numericText())`

## 7. 아이콘

SF Symbols만. 투약 `syringe`는 쓰지 않는다 (약물 연상 최소화) → 마디 `circle.grid.cross` 또는 `calendar.badge.clock`. 탭: `house`, `calendar`, `doc.text`. 설정 `gearshape`.

## 8. 앱 아이콘 방향

Midnight 배경에 가는 선으로 그린 마디(대나무 마디 또는 자의 눈금) 하나. 주사기·알약·체중계 금지.

## 9. 다크 전용 선언

Info.plist `UIUserInterfaceStyle = Dark`. 리포트 PDF 뷰는 `.environment(\.colorScheme, .light)`로 강제.
