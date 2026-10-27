"""앱 아이콘 (DESIGN_SYSTEM.md 6). Pillow 필요.

Apple 기본 앱 아이콘의 유리 문법을 참고한다(사람이 준 참고: 사진·팟캐스트·홈·나의 찾기):
밝거나 한 색조인 바탕, 채도 있는 반투명 유리 조각을 겹겹이, 겹친 곳은 색이 섞이고, 위쪽 가장자리에 빛 반사.

공통 마크: 양 끝이 둥근 캡슐형 막대 4개로 세운 "M" (앱 이름 마선생 / Masense에서 온 모노그램)
- 막대는 단색 유리. 두 색 나눔·가운데 이음선 같은 알약 표현, 주사기 형상은 쓰지 않는다 (DESIGN_SYSTEM.md 6 아이콘 금지)
- 의약품 상표·로고를 연상시키는 형태·색·서체는 쓰지 않는다 (COMPLIANCE.md 2.1-2)
- 빨강·초록은 쓰지 않는다 (판단하지 않는 색 원칙)

안:
- `petals` (1차안, 2026-10-22 사람 선택, 막대 굵기 136): 밝은 바탕 + 하늘·보라·파랑·남색 반투명 막대 4개가 겹쳐 M.
  겹친 곳은 색이 섞인다. 사진 앱 계열
- `liquid`: 밝은 바탕 + 파랑 동심원 원판 3겹(한 주씩 반복되는 마디의 리듬) + 흰 유리 M. 나의 찾기·팟캐스트 계열
- `rings`: 파랑 한 색조 바탕 + 반투명 동심원 + 흰 반유리 M
- `rings-midnight`: 같은 구성의 midnight 바탕

- `navy` (기본, 2026-10-23 사람 확정): 다크 네이비 그라데이션 바탕 위에 `rim`의 M을 오려 붙이고 아래에 제 색으로 은은하게 번지는 빛
- `rim` (2026-10-23 사람 선택 R2 "하이라이트 말고 유리 끝면 테두리 약간, 약간 맑은 유리, 굴절 조금"): 1차안 볼륨(136) × 1.28배,
  가장자리를 도는 가는 유리 테두리, 채움 0.84, 아래 그림을 살짝 비켜 비추는 굴절. 반짝임 같은 그림 요소 없음
- `clear`: 중간안. 막대 양 끝에 반사를 넣은 안 (사람이 "그림체 같다"며 뺌)
- `glass`: 같은 날의 중간안. 굵기 155·1.28배, 굴절·빛줄기·윤곽선을 강하게, `clarity`로 맑기 조절. 사람이 "볼륨은 1차안 정도"로 되돌림
- `mark`: 시작 전환 화면(SplashView)용. `rim`의 M 막대만 오려 낸 투명 PNG (바탕·그림자 없음, 여백 없이 자름)

출력: Masense/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png (1024×1024, RGB, 알파 없음)
실행: python3 scripts/make_app_icon.py [navy|rim|clear|glass|petals|liquid|rings|rings-midnight] [출력 경로]
      python3 scripts/make_app_icon.py mark  → Masense/Resources/Assets.xcassets/SplashMark.imageset/SplashMark.png
"""

import pathlib
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "Masense" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"

SIZE = 1024
SCALE = 4  # 4배로 그린 뒤 줄여 가장자리를 부드럽게
S = SIZE * SCALE

WHITE = (0xFF, 0xFF, 0xFF)
INK = (0xF2, 0xF5, 0xFA)
MIDNIGHT = (0x0B, 0x12, 0x20)

# 밝은 바탕 (기본 앱처럼 흰빛 → 옅은 회청)
LIGHT_TOP = (0xFF, 0xFF, 0xFF)
LIGHT_BOTTOM = (0xE6, 0xEB, 0xF3)

# 파랑 계열 유리 (accent #7FB3FF와 같은 계열)
BLUE_DEEP = (0x2F, 0x63, 0xF2)
BLUE = (0x4F, 0x86, 0xFF)
BLUE_LIGHT = (0x8C, 0xB6, 0xFF)
SKY = (0x4F, 0xC3, 0xF7)
INDIGO = (0x5B, 0x5F, 0xF0)
VIOLET = (0x9B, 0x6B, 0xF5)
SHADOW_BLUE = (0x1A, 0x2A, 0x6E)

# rings 안의 바탕
RINGS_TOP = (0x5A, 0x7B, 0xF0)
RINGS_BOTTOM = (0x33, 0x45, 0xC2)
RINGS_SHADOW = (0x14, 0x1E, 0x66)


def px(value: float) -> int:
    return round(value * SCALE)


def new_mask() -> Image.Image:
    return Image.new("L", (S, S), 0)


def solid(color: tuple) -> Image.Image:
    return Image.new("RGB", (S, S), color)


def vertical_fade(y0: int, y1: int, start: int, end: int) -> Image.Image:
    """y0에서 start, y1에서 end로 바뀌는 세로 그라데이션 (그 밖은 0)"""
    column = Image.new("L", (1, S), 0)
    for y in range(max(y0, 0), min(y1, S)):
        column.putpixel((0, y), round(start + (end - start) * (y - y0) / max(y1 - y0, 1)))
    return column.resize((S, S))


def gradient_background(top: tuple, bottom: tuple) -> Image.Image:
    return Image.composite(solid(bottom), solid(top), vertical_fade(0, S, 0, 255))


def scaled(mask: Image.Image, factor: float) -> Image.Image:
    return mask.point(lambda v: int(v * factor))


def soft_shadow(image: Image.Image, mask: Image.Image, color: tuple, offset: float, blur: float, strength: float) -> None:
    shadow = ImageChops.offset(mask, 0, px(offset)).filter(ImageFilter.GaussianBlur(px(blur)))
    image.paste(solid(color), (0, 0), scaled(shadow, strength))


def edge(mask: Image.Image, width: float) -> Image.Image:
    return ImageChops.subtract(mask, mask.filter(ImageFilter.MinFilter(px(width) * 2 + 1)))


def specular(image: Image.Image, mask: Image.Image, rim: int = 210, sheen: int = 70) -> None:
    """유리 빛 반사: 위가 밝은 테두리 + 위쪽 절반 광택"""
    _, y0, _, y1 = mask.getbbox()
    image.paste(solid(WHITE), (0, 0), ImageChops.multiply(edge(mask, 3), vertical_fade(y0, y1, rim, 20)))
    if sheen:
        image.paste(solid(WHITE), (0, 0), ImageChops.multiply(mask, vertical_fade(y0, y0 + (y1 - y0) * 45 // 100, sheen, 0)))


# MARK: 도형

def capsule(start: tuple, end: tuple, width: float) -> Image.Image:
    mask = new_mask()
    draw = ImageDraw.Draw(mask)
    draw.line([(px(x), px(y)) for x, y in (start, end)], fill=255, width=px(width))
    r = width / 2
    for x, y in (start, end):
        draw.ellipse([px(x - r), px(y - r), px(x + r), px(y + r)], fill=255)
    return mask


def m_segments(scale: float = 1.0) -> list:
    """M을 이루는 막대 4개의 양 끝점 (뒤 → 앞): 왼쪽 기둥, 오른쪽 기둥, 왼쪽 사선, 오른쪽 사선. scale은 가운데 기준 확대"""
    c = SIZE / 2

    def p(x: float, y: float) -> tuple:
        return (c + (x - c) * scale, c + (y - c) * scale)

    left, right, top, bottom = 322, 702, 352, 676
    valley = p(512, 590)
    return [
        (p(left, top), p(left, bottom)),
        (p(right, top), p(right, bottom)),
        (p(left, top), valley),
        (p(right, top), valley),
    ]


def m_bars(width: float = 96, scale: float = 1.0) -> list:
    """M을 이루는 막대 4개의 마스크 (뒤 → 앞)"""
    return [capsule(start, end, width * scale) for start, end in m_segments(scale)]


def disc(radius: float) -> Image.Image:
    mask = new_mask()
    c = SIZE / 2
    ImageDraw.Draw(mask).ellipse([px(c - radius), px(c - radius), px(c + radius), px(c + radius)], fill=255)
    return mask


# MARK: 안

def render_liquid() -> Image.Image:
    """밝은 바탕 + 파랑 동심원 3겹 + 흰 유리 M"""
    image = gradient_background(LIGHT_TOP, LIGHT_BOTTOM)
    for radius, color in [(410, BLUE_DEEP), (318, BLUE), (226, BLUE_LIGHT)]:
        mask = disc(radius)
        soft_shadow(image, mask, SHADOW_BLUE, 10, 22, 0.22)
        _, y0, _, y1 = mask.getbbox()
        # 원판도 유리: 위가 조금 밝다
        top_color = tuple(min(255, v + 26) for v in color)
        image.paste(Image.composite(solid(color), solid(top_color), vertical_fade(y0, y1, 0, 255)), (0, 0), mask)
        specular(image, mask, rim=170, sheen=34)

    for piece in m_bars(width=92, scale=0.86):
        soft_shadow(image, piece, SHADOW_BLUE, 12, 16, 0.42)
        image.paste(image.filter(ImageFilter.GaussianBlur(px(16))), (0, 0), piece)
        _, y0, _, y1 = piece.getbbox()
        image.paste(solid(WHITE), (0, 0), ImageChops.multiply(piece, vertical_fade(y0, y1, 242, 196)))
        specular(image, piece, rim=255, sheen=0)
    return image


def render_petals(width: float = 136) -> Image.Image:
    """밝은 바탕 + 색이 다른 반투명 막대 4개가 겹쳐 M. 겹친 곳은 곱하기로 섞인다. width: 막대 굵기(1024 기준)"""
    image = gradient_background(LIGHT_TOP, LIGHT_BOTTOM)
    colors = [SKY, VIOLET, BLUE, INDIGO]
    for piece, color in zip(m_bars(width=width), colors):
        soft_shadow(image, piece, color, 14, 20, 0.30)
        # 아래 그림과 곱해 섞고, 제 색 쪽으로 당긴다 (흰 바탕 위에서는 제 색, 다른 막대 위에서는 섞인 색)
        mixed = Image.blend(ImageChops.multiply(image, solid(color)), solid(color), 0.35)
        _, y0, _, y1 = piece.getbbox()
        lighter = Image.blend(mixed, solid(WHITE), 0.18)
        glass = Image.composite(mixed, lighter, vertical_fade(y0, y1, 0, 255))
        image.paste(glass, (0, 0), scaled(piece, 0.92))
        specular(image, piece, rim=230, sheen=60)
    return image


def render_clear(width: float = 136, scale: float = 1.28) -> Image.Image:
    """`petals`의 볼륨(막대 굵기 비율 136) + 유리 효과를 조금 올린 안 (2026-10-23 사람 요청: "딱 요정도 볼륨,
    약간 더 맑은 유리처럼, 끝부분 하이라이트 추가"). 앱 아이콘에서는 1.28배로 키워 타일을 채운다.
    `petals`보다: 채움을 덜 불투명하게(0.92 → 0.84) 밝게 섞어 맑게, 테두리 반사를 조금 더 밝게,
    막대 양 끝(둥근 마구리)에 흐리게 번지는 반사(위쪽 끝은 왼쪽 위, 아래쪽 끝은 아래 가장자리). 빛은 왼쪽 위에서 오므로 아래쪽 끝은 약하게"""
    image = gradient_background(LIGHT_TOP, LIGHT_BOTTOM)
    colors = [SKY, VIOLET, BLUE, INDIGO]
    bar = width * scale
    radius = bar / 2

    def disc_at(center: tuple, r: float) -> Image.Image:
        mask = new_mask()
        x, y = center
        ImageDraw.Draw(mask).ellipse([px(x - r), px(y - r), px(x + r), px(y + r)], fill=255)
        return mask

    for (start, end), color in zip(m_segments(scale), colors):
        piece = capsule(start, end, bar)

        def band(outer: float, inner: float) -> Image.Image:
            return ImageChops.subtract(capsule(start, end, bar - 2 * outer), capsule(start, end, bar - 2 * inner))

        _, y0, _, y1 = piece.getbbox()
        soft_shadow(image, piece, color, 14 * scale, 20 * scale, 0.26)
        # 아래 그림과 곱해 섞고 제 색 쪽으로 당긴다 (petals와 같은 섞임). 흰빛을 더 섞고 덜 불투명하게 칠해 맑게
        mixed = Image.blend(ImageChops.multiply(image, solid(color)), solid(color), 0.30)
        lighter = Image.blend(mixed, solid(WHITE), 0.26)
        image.paste(Image.composite(mixed, lighter, vertical_fade(y0, y1, 0, 255)), (0, 0), scaled(piece, 0.84))
        # 테두리 반사(위가 밝다)와 위쪽 광택
        image.paste(solid(WHITE), (0, 0), ImageChops.multiply(band(0, 3), vertical_fade(y0, y1, 245, 45)))
        image.paste(solid(WHITE), (0, 0), ImageChops.multiply(piece, vertical_fade(y0, y0 + (y1 - y0) * 45 // 100, 66, 0)))

        # 끝부분 하이라이트 (2026-10-23 "그림체 같지 않게"): 선을 그리지 않고 빛이 번지듯.
        # 마구리 가장자리를 따라 아주 가는 반사가 흐리게 돌고, 위쪽 끝은 왼쪽 위에 넓게 퍼지는 반사, 아래쪽 끝은 아래 가장자리에 옅은 빛
        for tip, other in ((start, end), (end, start)):
            dx, dy = tip[0] - other[0], tip[1] - other[1]
            length = max((dx * dx + dy * dy) ** 0.5, 1)
            ux, uy = dx / length, dy / length
            is_top = uy < 0
            cap = disc_at((tip[0] + ux * radius * 0.30, tip[1] + uy * radius * 0.30), radius * 0.95)
            rim = ImageChops.multiply(band(1, 4), cap).filter(ImageFilter.GaussianBlur(px(2.5)))
            image.paste(solid(WHITE), (0, 0), scaled(rim, 0.55 if is_top else 0.30))
            if is_top:
                center = (tip[0] - radius * 0.22, tip[1] - radius * 0.20)
                glow, blur, strength = disc_at(center, radius * 0.42), radius * 0.22, 0.42
            else:
                center = (tip[0] + ux * radius * 0.55, tip[1] + uy * radius * 0.55)
                glow, blur, strength = disc_at(center, radius * 0.50), radius * 0.26, 0.22
            glow = ImageChops.multiply(glow.filter(ImageFilter.GaussianBlur(px(blur))), piece)
            image.paste(solid(WHITE), (0, 0), scaled(glow, strength))
    return image


def render_rim(width: float = 136, scale: float = 1.28, rim: float = 0.65, fill: float = 0.84, refract: float = 0.07,
               inner_line: float = 0.0) -> Image.Image:
    """1차안(`petals`) 그대로에 유리 처리만 살짝 (2026-10-23 사람 요청: "하이라이트 말고 유리 끝면에 테두리 약간 유리효과,
    약간 맑은 유리로 굴절 조금만 더"). 반짝임·빛줄기 같은 그림 요소는 넣지 않는다.
    옵션 R1(rim 0.45, fill 0.88, refract 0.04)·R2(기본, 사람 선택)·R3(rim 0.75, fill 0.80, refract 0.10, inner_line 0.25) 중 R2
    - rim: 막대 가장자리를 따라 도는 가는 유리 테두리의 세기 (위가 조금 더 밝다)
    - fill: 채움 불투명도 (petals 0.92). 낮을수록 맑다
    - refract: 아래 그림을 비켜 비추는 정도 (막대 굵기 대비). 겹친 막대의 가장자리가 유리 안에서 살짝 꺾여 보인다
    - inner_line: 테두리 안쪽에 한 줄 더 비치는 유리 두께선의 세기 (0이면 없음)"""
    image = gradient_background(LIGHT_TOP, LIGHT_BOTTOM)
    colors = [SKY, VIOLET, BLUE, INDIGO]
    bar = width * scale
    for (start, end), color in zip(m_segments(scale), colors):
        piece = capsule(start, end, bar)

        def band(outer: float, inner: float) -> Image.Image:
            return ImageChops.subtract(capsule(start, end, bar - 2 * outer), capsule(start, end, bar - 2 * inner))

        _, y0, _, y1 = piece.getbbox()
        soft_shadow(image, piece, color, 14 * scale, 20 * scale, 0.30)
        backdrop = image
        if refract:
            backdrop = ImageChops.offset(image.filter(ImageFilter.GaussianBlur(px(2))), px(bar * refract * 0.6), px(bar * refract))
        # petals와 같은 섞임: 아래 그림과 곱해 섞고 제 색 쪽으로 당긴다. 맑을수록 흰빛을 조금 더
        clear = (0.92 - fill) / 0.92
        mixed = Image.blend(ImageChops.multiply(backdrop, solid(color)), solid(color), 0.35)
        lighter = Image.blend(mixed, solid(WHITE), 0.18 + clear * 0.5)
        image.paste(Image.composite(mixed, lighter, vertical_fade(y0, y1, 0, 255)), (0, 0), scaled(piece, fill))
        # petals의 반사 (위가 밝은 테두리 + 위쪽 광택)
        image.paste(solid(WHITE), (0, 0), ImageChops.multiply(band(0, 3), vertical_fade(y0, y1, 230, 20)))
        image.paste(solid(WHITE), (0, 0), ImageChops.multiply(piece, vertical_fade(y0, y0 + (y1 - y0) * 45 // 100, 60, 0)))
        # 유리 테두리: 가장자리를 따라 도는 가는 선, 위가 조금 더 밝다
        if rim:
            edge_line = band(0.6, 2.6).filter(ImageFilter.GaussianBlur(px(0.6)))
            image.paste(solid(WHITE), (0, 0), ImageChops.multiply(edge_line, vertical_fade(y0, y1, round(255 * rim), round(150 * rim))))
        if inner_line:
            thickness = band(6, 7.5).filter(ImageFilter.GaussianBlur(px(0.8)))
            image.paste(solid(WHITE), (0, 0), scaled(thickness, inner_line))
    return image


def render_navy(width: float = 136, scale: float = 1.28, top: tuple = (0x1C, 0x2D, 0x5A), bottom: tuple = (0x0D, 0x17, 0x33),
                mark=None) -> Image.Image:
    """다크 네이비 바탕 + `clear`의 M (2026-10-23 사람 요청 "다크네이비 배경"). 시작 화면에서 남색 위에 놓인 마크와 같은 모습.
    막대는 밝은 바탕에서 섞인 색 그대로 오려 붙이고(유리끼리 겹친 색이 살아 있게), 아래에 제 색으로 은은하게 번지는 빛을 깐다"""
    image = gradient_background(top, bottom)
    bars = m_bars(width=width, scale=scale)
    for piece, color in zip(bars, [SKY, VIOLET, BLUE, INDIGO]):
        glow = piece.filter(ImageFilter.GaussianBlur(px(38)))
        image.paste(solid(color), (0, 0), scaled(glow, 0.34))
    alpha = new_mask()
    for piece in bars:
        alpha = ImageChops.lighter(alpha, piece)
    image.paste(mark if mark is not None else render_rim(width, scale), (0, 0), scaled(alpha, 0.97))
    return image


def render_glass(width: float = 155, scale: float = 1.28, clarity: float = 1.0) -> Image.Image:
    """`petals`를 굵고 크게 + 유리 질감을 키운 안.
    2026-10-23 사람 요청 1: 더 굵게, 타일에 꽉 차게, 유리 효과 증대 → 굵기 155 × 1.28배
    2026-10-23 사람 요청 2: 같은 굵기에서 유리 테두리·굴절을 또렷하게, 조금 더 맑게 (clarity 0)
    2026-10-23 사람 요청 3: "맑은 유리" → clarity 1.0 (기본). 채움 불투명도 0.82 → 0.52, 섞는 색을 옅게,
      가장자리에만 짙은 색(빛이 길게 지나는 색유리 가장자리), 빛줄기·광택을 조금 더 밝게, 그림자는 옅게
    막대마다:
    - 굴절: 아래 그림을 막대 축의 오른쪽 아래로 비켜 비춘다. 겹친 막대의 가장자리가 유리 안에서 꺾여 보인다
    - 맑은 채움: 제 색을 옅게 섞고 위를 밝게. 아래가 비쳐 보이도록 불투명도를 낮춘다
    - 테두리: 바깥 가는 진한 선 + 그 안쪽 밝은 선(위가 더 밝다) + 가장자리가 밝아지는 두께감(프레넬)
    - 막대 축을 따라 흐르는 빛줄기, 아래쪽 안에서 돌아 나오는 빛, 제 색 그림자
    캡슐은 폭만 줄여 다시 그리면 안쪽으로 깎은 모양이 되므로, 테두리는 큰 침식 필터 대신 두 캡슐의 차로 만든다 (빠르다)"""
    image = gradient_background(LIGHT_TOP, LIGHT_BOTTOM)
    colors = [SKY, VIOLET, BLUE, INDIGO]
    bar_width = width * scale
    for (start, end), color in zip(m_segments(scale), colors):
        piece = capsule(start, end, bar_width)

        def inset(amount: float) -> Image.Image:
            return capsule(start, end, bar_width - 2 * amount)

        def band(outer: float, inner: float) -> Image.Image:
            return ImageChops.subtract(inset(outer), inset(inner))

        _, y0, _, y1 = piece.getbbox()
        soft_shadow(image, piece, color, 20, 32, 0.30 - 0.08 * clarity)

        # 굴절: 아래 그림을 조금 흐리게, 오른쪽 아래로 비켜 비춘다
        backdrop = ImageChops.offset(image.filter(ImageFilter.GaussianBlur(px(4))), px(bar_width * 0.05), px(bar_width * 0.08))
        mixed = Image.blend(ImageChops.multiply(backdrop, solid(color)), solid(color), 0.26 - 0.14 * clarity)
        top_tint = Image.blend(mixed, solid(WHITE), 0.40)
        bottom_tint = Image.blend(mixed, solid(SHADOW_BLUE), 0.05)
        glass_fill = Image.composite(bottom_tint, top_tint, vertical_fade(y0, y1, 0, 255))
        image.paste(glass_fill, (0, 0), scaled(piece, 0.82 - 0.30 * clarity))

        # 맑은 색유리: 가운데는 비치고 빛이 길게 지나는 가장자리에서 색이 짙다
        if clarity > 0:
            rim_tint = band(2.2, 24).filter(ImageFilter.GaussianBlur(px(8)))
            deep = Image.blend(solid(color), solid(SHADOW_BLUE), 0.15)
            image.paste(deep, (0, 0), scaled(ImageChops.multiply(rim_tint, piece), 0.50 * clarity))

        # 두께감: 가장자리 쪽이 밝아진다
        fresnel = band(0, 18).filter(ImageFilter.GaussianBlur(px(6)))
        image.paste(solid(WHITE), (0, 0), scaled(ImageChops.multiply(fresnel, piece), 0.30 - 0.10 * clarity))

        # 유리 막대의 반사: 축을 따라 왼쪽 위로 비켜 난 가는 빛줄기, 막대 안쪽에서만
        offset = bar_width * 0.17
        streak = capsule((start[0] - offset, start[1] - offset * 0.6), (end[0] - offset, end[1] - offset * 0.6), bar_width * 0.20)
        streak = streak.filter(ImageFilter.GaussianBlur(px(bar_width * 0.06)))
        streak = ImageChops.multiply(streak, inset(6))
        image.paste(solid(WHITE), (0, 0), scaled(streak, 0.62 + 0.18 * clarity))

        # 아래쪽 안에서 돌아 나오는 빛
        caustic = band(8, 20).filter(ImageFilter.GaussianBlur(px(4)))
        image.paste(solid(WHITE), (0, 0), ImageChops.multiply(caustic, vertical_fade(y0 + (y1 - y0) * 50 // 100, y1, 0, 150)))

        # 테두리: 바깥 가는 진한 선으로 윤곽을 세우고, 그 안쪽에 밝은 선 (위가 더 밝다)
        edge_color = Image.blend(solid(color), solid(SHADOW_BLUE), 0.45)
        image.paste(edge_color, (0, 0), scaled(band(0, 2.2), 0.55))
        image.paste(solid(WHITE), (0, 0), ImageChops.multiply(band(2.2, 6), vertical_fade(y0, y1, 255, 150)))
        # 위쪽 광택
        image.paste(solid(WHITE), (0, 0), ImageChops.multiply(piece, vertical_fade(y0, y0 + (y1 - y0) * 36 // 100, round(60 + 20 * clarity), 0)))
    return image


def render_rings(midnight: bool = False) -> Image.Image:
    """한 색조 바탕 + 반투명 동심원 + 흰 반유리 M"""
    if midnight:
        image, shadow_color = solid(MIDNIGHT), (0, 0, 0)
    else:
        image, shadow_color = gradient_background(RINGS_TOP, RINGS_BOTTOM), RINGS_SHADOW
    for radius, alpha in [(400, 0.11), (304, 0.14), (208, 0.18)]:
        mask = disc(radius)
        soft_shadow(image, mask, shadow_color, 8, 18, 0.18)
        image.paste(solid(INK), (0, 0), scaled(mask, alpha))
        _, y0, _, y1 = mask.getbbox()
        image.paste(solid(INK), (0, 0), ImageChops.multiply(edge(mask, 2), vertical_fade(y0, y1, 90, 10)))
    bars = m_bars()
    _, m_top, _, m_bottom = bars[0].getbbox()
    for piece in bars:
        soft_shadow(image, piece, shadow_color, 12, 16, 0.38)
        image.paste(image.filter(ImageFilter.GaussianBlur(px(18))), (0, 0), piece)
        image.paste(solid(INK), (0, 0), ImageChops.multiply(piece, vertical_fade(m_top, m_bottom, 235, 150)))
    return image


def render_mark(width: float = 136, scale: float = 1.28) -> Image.Image:
    """앱 아이콘(`rim`)의 M만 남긴 투명 이미지. 밝은 바탕 위에서 섞인 색 그대로, 막대 바깥(그림자·번짐)은 투명"""
    image = render_rim(width, scale).convert("RGBA")
    alpha = new_mask()
    for piece in m_bars(width=width, scale=scale):
        alpha = ImageChops.lighter(alpha, piece)
    image.putalpha(alpha)
    return image.crop(alpha.getbbox())


# 밝은 남색 바탕 옵션 (2026-10-27 사람 요청 "투명함을 살리고 바탕은 좀 밝은 남색")
NAVY_LIGHT = {
    "1": ((0x2A, 0x3F, 0x7C), (0x15, 0x22, 0x48)),  # 지금 navy보다 한 단계 밝은 남색
    "2": ((0x35, 0x4E, 0x92), (0x1B, 0x2B, 0x5C)),  # 중간
    "3": ((0x41, 0x5C, 0xA8), (0x24, 0x37, 0x72)),  # 파랑에 가까운 밝은 남색
}


def render_glass_navy(option: str = "2", width: float = 136, scale: float = 1.28, fill: float = 0.58, refract: float = 0.07,
                      rim: float = 0.75) -> Image.Image:
    """밝은 남색 바탕 위에 **진짜 비치는** 유리 M (D22 옵션). `navy`는 밝은 바탕에서 그린 M을 오려 붙여 불투명해 보였다.
    여기서는 막대를 남색 바탕 위에 직접 반투명으로 칠해 바탕과 아래 막대가 비친다.
    - 바탕: 밝은 남색 세로 그라데이션 + 왼쪽 위에서 비치는 옅은 빛
    - 막대: 아래 그림을 살짝 비켜 비춘(굴절) 위에 제 색을 fill만큼 덮고, 위쪽을 밝게. 겹친 곳은 두 색이 섞여 보인다
    - 가장자리를 도는 가는 유리 테두리(위가 더 밝다), 위쪽 광택, 막대 아래 제 색 번짐
    반짝임·빛줄기 같은 그림 요소 없음 (rim 안과 같은 원칙)"""
    top, bottom = NAVY_LIGHT[option]
    image = gradient_background(top, bottom)
    # 왼쪽 위 옅은 빛
    light = new_mask()
    ImageDraw.Draw(light).ellipse([px(-260), px(-300), px(760), px(620)], fill=255)
    image.paste(solid(WHITE), (0, 0), scaled(light.filter(ImageFilter.GaussianBlur(px(160))), 0.10))
    colors = [SKY, VIOLET, BLUE, INDIGO]
    bar = width * scale
    for (start, end), color in zip(m_segments(scale), colors):
        piece = capsule(start, end, bar)

        def band(outer: float, inner: float) -> Image.Image:
            return ImageChops.subtract(capsule(start, end, bar - 2 * outer), capsule(start, end, bar - 2 * inner))

        _, y0, _, y1 = piece.getbbox()
        # 제 색으로 번지는 빛 + 옅은 그림자
        glow = piece.filter(ImageFilter.GaussianBlur(px(34)))
        image.paste(solid(color), (0, 0), scaled(glow, 0.22))
        soft_shadow(image, piece, (0x08, 0x0E, 0x24), 12 * scale, 18 * scale, 0.28)
        # 굴절: 아래 그림을 조금 흐리게, 오른쪽 아래로 비켜
        backdrop = ImageChops.offset(image.filter(ImageFilter.GaussianBlur(px(2.5))), px(bar * refract * 0.6), px(bar * refract))
        # 반투명 색유리: 아래가 비치게 제 색을 덮고(screen 느낌으로 밝게), 위쪽은 흰빛을 더
        tinted = Image.blend(backdrop, solid(color), fill)
        lighter = Image.blend(tinted, solid(WHITE), 0.22)
        image.paste(Image.composite(tinted, lighter, vertical_fade(y0, y1, 0, 255)), (0, 0), piece)
        # 유리 테두리(위가 밝다) + 위쪽 광택
        edge_line = band(0.6, 2.8).filter(ImageFilter.GaussianBlur(px(0.6)))
        image.paste(solid(WHITE), (0, 0), ImageChops.multiply(edge_line, vertical_fade(y0, y1, round(255 * rim), round(120 * rim))))
        image.paste(solid(WHITE), (0, 0), ImageChops.multiply(piece, vertical_fade(y0, y0 + (y1 - y0) * 45 // 100, 58, 0)))
        # 가장자리 두께감 (프레넬)
        fresnel = band(0, 14).filter(ImageFilter.GaussianBlur(px(5)))
        image.paste(solid(WHITE), (0, 0), scaled(ImageChops.multiply(fresnel, piece), 0.16))
    return image


VARIANTS = {
    "glass-navy-1": lambda: render_glass_navy("1"),
    "glass-navy-2": lambda: render_glass_navy("2"),
    "glass-navy-3": lambda: render_glass_navy("3"),
    "glass-navy-2-clear": lambda: render_glass_navy("2", fill=0.46),
    "liquid": render_liquid,
    "petals": render_petals,
    "rings": render_rings,
    "rings-midnight": lambda: render_rings(midnight=True),
    "mark": render_mark,
    "glass": render_glass,
    "clear": render_clear,
    "navy": render_navy,
    "rim": render_rim,
}

MARK_OUT = ROOT / "Masense" / "Resources" / "Assets.xcassets" / "SplashMark.imageset" / "SplashMark.png"


def main() -> None:
    variant = sys.argv[1] if len(sys.argv) > 1 else "navy"
    out = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else (MARK_OUT if variant == "mark" else OUT)
    image = VARIANTS[variant]()
    # 4배로 그린 것을 1/4로 줄인다 (아이콘은 1024×1024, 마크는 자른 크기의 1/4)
    image = image.resize((image.width // SCALE, image.height // SCALE), Image.LANCZOS)
    out.parent.mkdir(parents=True, exist_ok=True)
    image.save(out, "PNG", optimize=True)
    print(f"wrote {out} {image.size} {image.mode} ({variant})")


if __name__ == "__main__":
    main()
