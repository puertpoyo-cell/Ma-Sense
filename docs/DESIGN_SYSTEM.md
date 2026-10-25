# DESIGN_SYSTEM — Midnight / Frost (Blueprint Edition)

Deep Midnight Navy 배경 위에 상단 하이라이트 보더가 적용된 Frosted Glass 카드를 얹고, 건축 도면(Blueprint)처럼 정밀하게 구획된 셀 그리드와 치수 표기 타이포그래피를 사용합니다. 모든 토큰과 컴포넌트 이름은 `Masense/DesignSystem/` 아래의 코드 식별자와 1:1로 맞춥니다.

> 2026-10-21 Blueprint Edition으로 교체. 이전 판(Midnight / Frost)의 토큰·컴포넌트는 그대로 두고 도면 그리드, 치수 표기, 하이라이트 보더, 하이브리드 카운트다운, 바디맵 이력 표시를 더했습니다. 초안과 코드가 다르던 부분은 8절에 정리했습니다.

---

## 1. 핵심 시각 원칙

1. **건축 도면(Blueprint) 셀 그리드**
   - 카드 안에 카드를 중첩하지 않습니다.
   - 카드 내부는 `gridHairline`(`white.opacity(0.08)`, 1px) 가로·세로 선으로 2컬럼 또는 4컬럼 셀로 구획하고, 선이 교차하거나 분기하는 지점에 미세한 십자 마커(`+`, `gridCrosshair`)를 둡니다.
   - 격자선과 텍스트 사이에는 최소 `s3`(12pt) 여백을 둡니다.
2. **도면 치수 기입식 수치·단위 위계 (`DimensionValue`)**
   - 셀 안에서 라벨은 좌측 상단, 수치는 우측 하단 정렬이 기본입니다.
   - 숫자 본체는 `ink` + 큰 폰트(`metricLarge` 등), 바로 뒤의 단위(`kg`, `g`, `회`, `일`)와 분모(`/ 12`)는 한 단계 작은 폰트(`label` 또는 `caption`) + `inkSecondary`로 낮춥니다.
3. **비판단 색채와 톤**
   - 앱과 리포트 어디에도 빨강(경고·실패)·초록(성공·달성)을 쓰지 않습니다.
   - 심각도 3, 투약 누락, 예정일 지남(`.overdue`)도 텍스트, 볼드체, 테두리 명도로만 구분합니다.
   - 느낌표·이모지를 쓰지 않으며, 기록 완료 피드백은 하단 토스트 "기록했습니다."로 통일합니다.
4. **이원화된 컬러 스킴**
   - 앱 UI는 다크 고정 (`INFOPLIST_KEY_UIUserInterfaceStyle = Dark`, `.preferredColorScheme(.dark)`).
   - 진료 전 리포트 PDF(`ReportPage`)만 인쇄·의사 가독성을 위해 라이트(`.environment(\.colorScheme, .light)`)로 강제합니다.

---

## 2. 색·재질 토큰 (`Color+Tokens.swift`)

| 토큰 | 앱 (다크 고정) | 리포트 PDF (라이트) 토큰 · 값 | 용도·규칙 |
|---|---|---|---|
| `midnight` | `#0B1220` | `paperBackground` `#FFFFFF` | 앱 배경. 좌상단에 `accent.opacity(0.06)` 방사형 그라데이션 1개 |
| `midnightElevated` | `#111B2E` | — | 시트 배경 |
| `frost` | `white.opacity(0.08)` + `.ultraThinMaterial` | — | 카드 채움 |
| `frostBorder` | `white.opacity(0.14)` | `paperBorder` `#CBD5E1` | 기본 1px 외곽선 (칩, GhostButton, 리포트 칸 테두리) |
| `frostHighlightTop` | `white.opacity(0.22)` | — | `FrostCard` 테두리 그라데이션 위쪽, 심각도 3 강조 테두리 |
| `frostHighlightBottom` | `white.opacity(0.10)` | — | `FrostCard` 테두리 그라데이션 아래쪽 |
| `gridHairline` | `white.opacity(0.08)` | `paperHairline` `#E2E8F0` | 카드 내부 1px 도면 분할선 |
| `gridCrosshair` | `#5E6B82` × `0.5` | `paperInkTertiary` `#9CA3AF` | 분할선 교차점 `+` 마커 |
| `ink` | `#F2F5FA` | `paperInk` `#111827` | 본문, 핵심 숫자 |
| `inkSecondary` | `#9AA7BD` | `paperInkSecondary` `#4B5563` | 보조 텍스트, 숫자 옆 단위·분모, 셀 라벨 |
| `inkTertiary` | `#5E6B82` | `paperInkTertiary` `#9CA3AF` | 비활성, 차트 축·보조선, 빈 슬롯 |
| `accent` | `#7FB3FF` | `paperAccent` `#2563EB` | Primary 버튼, 선택, 직전 1회 투약 부위, 스파크라인 |
| `accentSoft` | `accent.opacity(0.18)` | — | 선택된 칩, 강도 1·2, "① 마지막" 칩 배경 |
| `siteRecent(rank:)` | `accent` × `1.0 / 0.45 / 0.35 / 0.25` | — | 바디맵 최근 사용 이력. 0이 직전 1회 (5.3) |
| `notice` | `#E8D9A8` | — | 건강 관련 중립 안내 (`NoticeLine`, 경고 아님) |
| `prescription(slot:)` | `#7FB3FF` · `#E9BE6C` · `#B9A3FF` · `#C3CEDD` | `paperPrescription(slot:)` `#2F6FD6` · `#A86B12` · `#6B4FC9` · `#56657D` | 처방 구간 색 (D7, R13-2). 처방 시작 순서대로 돌려 쓴다. 순서·강도 의미 없음, 빨강·초록 없음. 용량 단계 표시에 쓰지 않는다 |

- **유료 테마 (`UserSettings.reportTheme`)**: 비소모성 구매 시 `accent` 1종만 바꿉니다 — `midnight`(기본 `#7FB3FF`, 리포트 `#2563EB`), `sand`(`#E8C9A0`), `sage`(`#A8D5BA`). 리포트에서 강조색은 헤더 2pt 선에만 쓰므로 sand·sage는 같은 값을 씁니다.

---

## 3. 타이포그래피 (`Typography.swift`)

시스템 폰트(SF Pro / Apple SD Gothic Neo), Dynamic Type 대응 (A4 리포트 PDF는 고정 크기). 숫자에는 `.monospacedDigit()`.

| 토큰 | 규격 | 용도 |
|---|---|---|
| `display` | 56pt, `.bold`, `.rounded`, monospacedDigit | 카운트다운 (`D-3`, `D-Day`, `D+1`). 앱에서는 `@ScaledMetric`으로 키운다 |
| `metricLarge` | 28pt, `.semibold`, monospacedDigit | 셀 핵심 수치 (`78.4`, `3`, `18시간 42분`) |
| `title` | `.title2`, `.semibold` | 화면·시트 제목 |
| `sectionHeader` | `.headline`, `.semibold` | 카드 좌측 상단 섹션 제목 (`오늘의 마디`) |
| `body` | `.body`, monospacedDigit, 줄 간격 `bodyLineSpacing` 4 | 본문 |
| `label` | `.subheadline`, `.medium` | 버튼, 칩, `metricLarge` 옆 단위 |
| `caption` | `.caption`, monospacedDigit, 색 `inkSecondary` | 날짜, 출처, 작은 수치 옆 단위, 셀 라벨 |
| `mono` | `.body.monospaced()` | 회차 코드, 리포트 마디 칸 |

---

## 4. 간격·격자·모서리 (`Spacing.swift`)

- 4pt 단위: `s1 = 4`, `s2 = 8`, `s3 = 12`, `s4 = 16`, `s5 = 24`, `s6 = 32`, `s7 = 48`
- 화면 좌우 `screenHorizontal = s5`, 카드 간 `cardGap = s4`, 카드 내부 `cardPadding = s5`
- 도면 셀 내부 `cellPadding = s4` (격자선과 콘텐츠 사이 최소 `s3`)
- `Radius`: `card = 20`, `button = 14`, `chip = 10`

---

## 5. 컴포넌트

### 5.1 `FrostCard` · `BlueprintDivider` · `BlueprintCell` · `BlueprintSplit`
- 그림자 없음. `.ultraThinMaterial` 위에 `frost`, 외곽선은 위 `frostHighlightTop` → 아래 `frostHighlightBottom` 1px 리니어 그라데이션.
- `FrostCard(padding:)`: 도면 셀로 꽉 채우는 카드는 `padding: 0`, 셀이 각자 `cellPadding`을 가진다.
- `BlueprintDivider(axis:crosshair:)`: `gridHairline` 1px 선 + `+` 마커. 마커 위치 `.center`(기본) / `.leading` / `.trailing` / `.none`. 세로 선과 만나는 가로 선은 `.leading`으로 교차점에 마커를 둔다.
- `BlueprintCell(label:)`: 라벨 좌측 상단(`caption`, `inkSecondary`), 값 우측 하단.
- `BlueprintSplit`: 두 셀을 세로 분할선으로 나눈다. 접근성 글자 크기에서는 위아래로 쌓고 가로 분할선으로 나눈다.
- `BlueprintGridLines(rows:columns:)`: 같은 크기 칸이 반복되는 격자(기록 탭 습관 캘린더)에 `.overlay`로 얹는다. 칸 사이 `gridHairline` 1px, 안쪽 교차점마다 팔 3pt `+`(`gridCrosshair`). 바깥 테두리는 그리지 않는다.
- 리스트·폼 화면(기록 탭, 설정, 입력 시트)은 카드 대신 `.frostRow()` 행을 쓴다: 배경 `frost`, 행 구분선 `gridHairline`. 섹션 헤더는 `SectionHeaderText`(`label` + `inkSecondary`, 대문자 변환 없음).

### 5.2 `CountdownHero` (하이브리드 카운트다운)
`RULES.md` R2 상태와 남은 시간에 따라 좌측 메인 셀과 우측 보조 셀(위·아래 2분할)을 그린다.

좌측 메인 셀:
1. `.due`, 남은 시간 **24시간 이상**: 라벨 "다음 투약", `D-n` (`display`), 캡션 "다음 투약까지". n은 달력 날짜 차이
2. `.due`, 남은 시간 **24시간 미만**: `D-Day` (`display`), 캡션 "다음 투약까지", **`18시간 42분`** (`metricLarge`, 단위는 `label`) + "남음"
3. `.overdue`: `D+n` (`display`, 색 변화 없음) + 캡션 "예정일이 지났습니다". 예정일 당일이면 `D-Day`
4. `.done`: "기록 완료" (`title`) + 다음 마디 `D-n` 보조 표기
5. 처방 소진(`nil`): "새 처방을 입력하세요" (`title`)

우측 보조 셀:
- 위: 라벨 "예정 시간", 값 "목요일 20:00" (지금 마디, 완료면 다음 마디)
- 아래: 라벨 "회차", 값 `7` + 분모 `/ 12` (`DimensionValue`)

버튼(셀 아래, 분할선 다음 행): 24시간 미만·지남 → `PrimaryButton` "투약 기록". 24시간 이상이지만 이미 그 마디 구간 안(예정일 이틀 전부터, R1) → `GhostButton` "투약 기록". 소진 → `PrimaryButton` "처방 입력". 처방 없음은 빈 상태 문구 + "처방 입력".

### 5.3 `BodyMapView` (전면 고정 + 하이브리드 이력)
- 전면 1장 고정. 성별 표현 없는 중성 실루엣 한 줄 윤곽(`BodySilhouette`, 머리·목·어깨·팔·몸통·다리를 곡선 하나로). 전·후면 토글 없음.
- 2026-10-25 사람 요청("아직 이상하다", 참고 이미지 제공)으로 머리부터 발까지 실제 비율로 다시 그림: 둥근 어깨, 몸에서 조금 떨어져 손끝이 허벅지 중간에 오는 팔, 허리·골반 곡선, 무릎·종아리·발목, 작은 발. 설계 좌표 240×420, 배꼽 점 하나. 평균 체형 한 가지만 쓰고 체형을 단계로 바꾸지 않는다 (COMPLIANCE.md 2.2). 참고한 스톡 이미지는 쓰지 않고 직접 그린 곡선
- 실루엣은 유리 스타일 (D10, 2026-10-25 사람 선택 "B 유리"): 채움 `frostHighlightBottom` → `frost` 50% 세로 그라데이션, 테두리 1pt `frostHighlightTop` → `frostHighlightBottom`. 상자를 이어 붙인 이전 그림을 대신한다
- 8구역(`BodySite`): 복부 4, 허벅지 2, 상완 2. 거울처럼 화면 왼쪽이 본인의 왼쪽이고(2026-10-24 사람 결정, 이전에는 마주 보는 정면), 그림 아래에 "왼쪽 / 오른쪽" 라벨을 둔다. 아래 부위별 표도 같은 순서.
- 이력 표시 (`RULES.md` R6 — **부위 추천 금지**, 화살표·"다음은" 표시 없음):
  1. **직전 1회**: 구역을 `accent` 1.0으로 채우고, 그림 아래 첫 행에 `accentSoft` 칩 **"① 마지막: 복부 왼쪽 아래 (10/16)"**
  2. **이전 2~4회**: 구역은 `siteRecent` 0.45 → 0.25 + 얇은 `accent` 테두리
  3. **부위별 마지막 날짜** (D5, 2026-10-22 사람 결정): 쓴 적 있는 구역마다 마지막 사용일 `M/d`를 9pt semibold로 적는다(직전 1회 구역은 `midnight` 글자, 나머지 `ink`). 칩 아래에 "부위별 마지막 사용" 표 — 그림과 같은 방향으로 두 칸씩(팔·복부 위·복부 아래·허벅지), 쓴 적 없는 부위는 `inkTertiary` "—". 이전의 "② 이전" 텍스트 행은 이 표로 바꿨다
  4. **선택 상태** (`DoseLogSheet`): 탭한 구역은 `accent` 채움 + `ink` 1.5px 테두리 + 체크 아이콘 (색만으로 구분하지 않기 위해). 선택한 구역에는 날짜 대신 체크만

### 5.4 `SymptomChip` (48h 컨디션 체크)
- 한 줄: 좌측 증상 이름, 우측 강도 `0 | 1 | 2 | 3` 세그먼트 트랙. 시트 위에 범례 "0 없음 · 1 약함 · 2 보통 · 3 심함".
- 선택된 칸의 표현 (색으로 판단하지 않음):
  - `0`: `inkTertiary` 텍스트, 배경 없음
  - `1`·`2`: `accentSoft` 배경 + `accent` 텍스트
  - `3`: 빨강 금지. `ink` 볼드 + `frostHighlightTop` 1.5px 테두리. 증상 이름도 볼드
- 강도 3이 하나라도 있으면 시트 하단에 `NoticeLine` "증상이 심하면 의사와 상담하세요." (`symptom.severe`) 고정.

### 5.5 `WeekSparkline` · `WeekChart` (체중 추이)
- R7 주 평균. 샘플 없는 주는 보간하지 않고 선을 끊는다.
- 투약일마다 4pt 세로 눈금.
- `WeekSparkline`(홈)은 축 라벨 없음. `WeekChart`(기록 탭·리포트)는 y축 최소·최대 2개, x축 주 시작일.
- 최근 2주 연속 주당 감소가 1.0 kg를 넘을 때만 카드 하단 `NoticeLine`(`pace.notice`) + 출처 한 줄(`pace.source`, `inkTertiary`). `AppConfig.paceGuideSource`가 nil이면 숨긴다 (COMPLIANCE.md 2.2).

### 5.6 `MealSlotRow`와 습관·운동 UI (M2)
- 홈 "오늘의 마디": 끼니 4칸(아침·점심·저녁·간식)은 8×8pt 원형 도트. 기록한 끼니만 `accent`로 채운다. 빈 끼니에 "건너뜀" 단어·아이콘 없음.
- 단백질·근력운동은 게이지 바 없이 도면 수치로만: 단백질 `65` + `g` (목표가 있으면 `/ 90 g`, 채운 날은 "채웠습니다"), 근력운동 `2` + `회`.
- 저컨디션 연동 (조건이 둘로 나뉜다):
  - **식욕 저하일** (`isLowAppetiteDay`, R10): 최근 48h 체크에 구역 ≥ 2 또는 식욕 ≠ 평소 → `ProteinSheet` 맨 위·홈 카드에 "작게 자주"(단백질 셰이크, 그릭요거트, 콩·두유, 계란)
  - **저컨디션 날** (`isLowConditionDay`, R11): 최근 48h 체크에 강도 2 이상 증상 → `StrengthSheet`에서 걷기 · 스트레칭 · 쉬기를 근력 위에

### 5.7 `NoticeLine` · `PrimaryButton` · `GhostButton` · `RecordedToast` · `DimensionValue`
- `NoticeLine`: `info.circle` + `notice` 색 텍스트. 경고 삼각형(`exclamationmark.triangle`) 금지.
- `PrimaryButton`: 높이 52pt, 모서리 14pt, `accent` 배경, `midnight` 텍스트.
- `GhostButton`: 높이 52pt, 모서리 14pt, 배경 없음, `frostBorder` 1px, `ink` 텍스트.
- `RecordedToast`: 하단 캡슐, "기록했습니다." 1.2초 후 사라짐. 축하 애니메이션 없음, `UIImpactFeedbackGenerator(style: .light)` 1회.
- `DimensionValue(value, unit:)`: 숫자 `metricLarge`·`ink`, 단위 `label`·`inkSecondary`, 첫 줄 기준선 정렬, 숫자 변경은 `.contentTransition(.numericText())`.

---

## 6. 내비게이션·시트·모션·아이콘

- **탭 3개 + 설정 push**: 홈 `house`, 기록 `calendar`, 리포트 `doc.text`. 설정은 홈 우측 상단 `gearshape`.
- **시트**: 배경 `midnightElevated`, 그래버 표시(`.presentationDragIndicator(.visible)`).
  - `.medium`: `WeightEntrySheet`, 구매 시트
  - `.large`: `DoseLogSheet`, `ConditionCheckSheet`, `ProteinSheet`, `StrengthSheet`, `PrescriptionSheet`
- **모션**: 카드 등장 `opacity 0→1` + `offset(y: 8→0)`, `.easeOut(duration: 0.25)` (손쉬운 사용 "동작 줄이기"면 생략). 숫자 변경 `.contentTransition(.numericText())`. 축하 애니메이션 없음.
- **시작 전환 화면** (`SplashView`, D5, 2026-10-22 사람 요청): 앱을 새로 열 때 `midnight` 바탕에 앱 아이콘의 M 마크(`SplashMark`, `make_app_icon.py mark`, 폭 112pt) + "마선생" + "처방은 의사가, 기록은 마선생이."를 1초 보여 준 뒤 `opacity`만 0.3초 `easeOut`으로 사라진다. 크기·회전 애니메이션 없음. 그동안 아래에서 온보딩·홈을 준비한다. 시스템 시작 화면 바탕도 같은 `midnight`(`LaunchBackground` 색, Info.plist `UILaunchScreen`)라 색이 튀지 않는다
- **아이콘 금지**: `syringe`(주사기), `pills`(알약), 체중계(`scalemass`) 심볼. 투약·마디 아이콘은 `circle.grid.cross` 또는 `calendar.badge.clock`만.
- **앱 아이콘**: `midnight` 배경 위에 건축 스케일(자의 눈금)과 마디를 결합한 수직·수평 도면 선.
  - **확정안 "네이비 유리 M"** (2026-10-23 사람 확정, 기본 `navy` + `rim` R2): 다크 네이비 그라데이션 바탕(`#1C2D5A` → `#0D1733`) 위에 유리 M. M은 1차안 그대로(막대 굵기 비율 136, 4색 반투명 막대가 겹쳐 섞임)를 1.28배로 키워 타일을 채운다. 유리 처리는 살짝만: 가장자리를 따라 도는 가는 유리 테두리(위가 조금 밝음), 조금 더 맑은 채움(불투명도 0.92 → 0.84), 아래 그림을 살짝 비켜 비추는 굴절(겹친 막대 가장자리가 유리 안에서 조금 꺾여 보임). 반짝임·빛줄기·초승달 같은 그림 요소는 넣지 않는다(사람이 "그림체 같다"며 뺌). 막대 아래에 제 색으로 은은하게 번지는 빛. 시작 전환 화면의 `SplashMark`도 같은 M
  - 중간안 `glass` (같은 날): 굵기 155로 키우고 굴절·빛줄기·윤곽선을 강하게 한 안. 사람이 보고 "볼륨은 1차안 정도"로 되돌렸다. 스크립트에 대안으로 남김
  - 1차안 "겹친 유리 M" (2026-10-22 사람 선택, `petals`, 막대 굵기 136): Apple 기본 앱(사진·팟캐스트·홈·나의 찾기)의 유리 문법을 참고. 밝은 바탕(흰빛 → 옅은 회청) 위에 하늘(왼쪽 기둥)·보라(오른쪽 기둥)·파랑·남색(두 사선) 반투명 캡슐 막대 4개가 겹쳐 M을 이룬다. 겹친 곳은 색이 곱해져 섞이고(가운데 골이 가장 진함), 막대마다 위가 밝은 테두리·위쪽 광택·제 색 그림자
  - 대안: `liquid`(밝은 바탕 + 파랑 동심원 3겹 + 흰 유리 M), `rings`·`rings-midnight`(파랑 한 색조 또는 midnight 바탕 + 반투명 동심원 + 흰 반유리 M). 굵기 비교는 `render_petals(width:)`
  - 바탕은 다크 네이비(2026-10-23 사람 결정, 1차안의 밝은 바탕에서 바꿈). 앱 안 `midnight`보다 푸른 기가 있어 홈 화면에서 구분된다. 빨강·초록은 쓰지 않는다
  - 막대는 단색이다. 두 색 나눔·가운데 이음선 같은 알약 표현과 주사기 형상은 쓰지 않는다 (위 아이콘 금지)
  - 모노그램은 앱 이름(마선생 / Masense)에서만 가져온다. 의약품 상표·로고를 연상시키는 형태·색·서체는 쓰지 않고, 홍보에서도 약과 연결하지 않는다 (COMPLIANCE.md 2.1-2)
  - 1024×1024 RGB(알파 없음) 한 장, 글꼴 파일 없이 선·원으로 그린다. 앱 이름은 "마선생"으로 확정 (2026-10-22)

---

### 6-1. 마선생 캐릭터 (D12, 2026-10-25 사람 결정)
- 안경 쓴 젊은 선생님의 얼굴과 어깨, 체크리스트 판(체크 2개·빈칸 1개)을 잡은 손. 둥근 얼굴·큰 동그란 안경·볼 홍조로 귀엽게, 니트(파랑)에 셔츠 깃. 바탕은 `midnight` 계열 남색 원
- 흰 가운·청진기·적십자·주사기·알약은 그리지 않는다 (COMPLIANCE.md 3.1, 위 아이콘 금지)
- 앱 안에서만 쓴다(오늘 1-0 마선생 한마디). 홈 화면 앱 아이콘은 "네이비 유리 M" 그대로
- 원본 `docs/design/masense_coach.svg`(512 기준), 에셋 `MasenseCoach` 72pt @1x·@2x·@3x PNG (원 밖 투명)

## 7. 참조 구현 (`Masense/DesignSystem/`)

실제 코드가 기준입니다. 아래는 핵심만 옮긴 것입니다.

| 파일 | 내용 |
|---|---|
| `Color+Tokens.swift` | 2절 토큰, `paper*` 리포트 토큰, `siteRecent(rank:)`, `Color(hex:)` |
| `Typography.swift` | 3절 폰트 토큰 |
| `Spacing.swift` | 4절 간격·모서리 |
| `FrostCard.swift` | `FrostCard(padding:)` (하이라이트 보더, 등장 모션) |
| `Blueprint.swift` | `BlueprintDivider`, `BlueprintCell`, `BlueprintSplit`, `BlueprintGridLines` |
| `FormStyle.swift` | 리스트·폼 행 `.frostRow()`, 섹션 헤더 `SectionHeaderText` |
| `DimensionValue.swift` | 수치 + 단위 |
| `PrimaryButton.swift` | `PrimaryButton`, `GhostButton`, 버튼 스타일 |
| `NoticeLine.swift`, `RecordedToast.swift`, `SymptomChip.swift`, `MealSlotRow.swift`, `WeekSparkline.swift`, `WeekChart.swift`, `AdaptiveStack.swift`, `MidnightBackground.swift` | 5절 컴포넌트 |

```swift
// FrostCard: 그림자 없이 하이라이트 그라데이션 보더
struct FrostCard<Content: View>: View {
    var padding: CGFloat = Spacing.cardPadding
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .background(Color.frost)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [.frostHighlightTop, .frostHighlightBottom], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

// DimensionValue: 숫자는 크고 진하게, 단위는 작고 옅게. 단위는 문자열 카탈로그 키
struct DimensionValue: View {
    let value: String
    var unit: LocalizedStringKey?
    var valueFont: Font = Typography.metricLarge
    var unitFont: Font = Typography.label

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s1) {
            Text(verbatim: value).font(valueFont).foregroundStyle(Color.ink).contentTransition(.numericText())
            if let unit {
                Text(unit).font(unitFont).foregroundStyle(Color.inkSecondary)
            }
        }
    }
}
```

---

## 8. 초안과 코드의 차이 (2026-10-21 정리)

받은 초안의 7절 참조 코드와 기존 코드·규약이 다른 부분은 아래처럼 맞췄습니다.

| 초안 | 코드 | 이유 |
|---|---|---|
| `MasenseFont` | `Typography` | 이미 모든 화면이 쓰는 이름. 1:1 원칙 |
| `frostSurface` | `frost` | 2절 표의 토큰 이름과 기존 코드 |
| 버튼·`NoticeLine`이 `String` 제목을 받음 | `LocalizedStringKey`를 받음 | CLAUDE.md: 문구는 `Localizable.xcstrings`, 뷰에 하드코딩 금지 |
| 토스트 키 `recorded.toast` | `toast.recorded` | 기존 키 유지 |
| `siteRecent` 1.0 / 0.7 / 0.45 / 0.25 (2절) | 1.0 / 0.45 / 0.35 / 0.25 | 5.3 "직전 1회만 선명, 이전은 0.45 → 0.25"와 맞춤 |
| 리포트 라이트 값을 같은 토큰 이름으로 표기 | `paper*` 토큰 | 앱은 다크 고정이라 같은 이름에 두 값을 두지 않는다 |
| R10·R11 저컨디션 조건 하나로 통합 (이전 구현) | `isLowAppetiteDay`(R10)·`isLowConditionDay`(R11) 분리 | 5.6이 두 조건을 구분 |
