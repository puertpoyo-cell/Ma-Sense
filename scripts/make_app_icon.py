"""앱 아이콘: 유리판 위 이름 모노그램 (DESIGN_SYSTEM.md 6). Pillow 필요.

미니멀 + 글래스모피즘. 앱의 FrostCard와 같은 재질 언어를 쓴다.
- midnight 배경 뒤에 accent 계열 빛 두 덩이가 번지고, 그 위에 반투명 유리판(뒤를 흐리게 비침)
- 유리판 테두리는 위가 밝고 아래로 옅어지는 그라데이션 (frostHighlightTop → Bottom)
- 모노그램은 앱 이름(마선생 / Masense)에서만 가져온다. 의약품 상표·로고를 연상시키는 형태·색은 쓰지 않는다 (COMPLIANCE.md 2.1-2)
  - `ma` (기본): 기하 도형으로 그린 "Ma". M은 ink, a는 accent = 이번 마디
  - `hangul`: "마". ㅁ은 도면 칸, ㅏ의 가로획은 자의 눈금이고 끝의 accent 점이 이번 마디
- 글꼴 파일을 쓰지 않고 선·원으로 그린다 (라이선스 걱정 없음)

출력: Masense/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png (1024×1024, RGB, 알파 없음)
실행: python3 scripts/make_app_icon.py [ma|hangul] [출력 경로]
"""

import pathlib
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "Masense" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"

SIZE = 1024
SCALE = 4  # 4배로 그린 뒤 줄여 가장자리를 부드럽게
S = SIZE * SCALE

# DESIGN_SYSTEM.md 2 토큰 (빨강·초록 없음)
MIDNIGHT = (0x0B, 0x12, 0x20)
INK = (0xF2, 0xF5, 0xFA)
ACCENT = (0x7F, 0xB3, 0xFF)
INDIGO = (0x4F, 0x6B, 0xE8)  # 배경 빛 두 번째 덩이. accent와 같은 파랑 계열

# 유리판
PANEL = 640
PANEL_RADIUS = 168
CENTER = (512, 512)


def px(value: float) -> int:
    return round(value * SCALE)


def blob(image: Image.Image, color: tuple, center: tuple, radius: float, alpha: int, blur: float) -> None:
    mask = Image.new("L", (S, S), 0)
    cx, cy = center
    ImageDraw.Draw(mask).ellipse([px(cx - radius), px(cy - radius), px(cx + radius), px(cy + radius)], fill=alpha)
    mask = mask.filter(ImageFilter.GaussianBlur(px(blur)))
    image.paste(Image.new("RGB", (S, S), color), (0, 0), mask)


def background() -> Image.Image:
    image = Image.new("RGB", (S, S), MIDNIGHT)
    blob(image, ACCENT, (290, 280), 270, 165, 140)
    blob(image, INDIGO, (770, 780), 260, 150, 140)
    return image


def panel_box() -> list:
    cx, cy = CENTER
    half = PANEL / 2
    return [px(cx - half), px(cy - half), px(cx + half), px(cy + half)]


def rounded_mask(box: list, radius: float, inset: float = 0) -> Image.Image:
    mask = Image.new("L", (S, S), 0)
    x0, y0, x1, y1 = box
    ImageDraw.Draw(mask).rounded_rectangle(
        [x0 + px(inset), y0 + px(inset), x1 - px(inset), y1 - px(inset)], radius=px(radius - inset), fill=255
    )
    return mask


def vertical_fade(y0: int, y1: int, start: int, end: int) -> Image.Image:
    """y0에서 start, y1에서 end로 선형으로 바뀌는 세로 그라데이션 (그 밖은 0)"""
    column = Image.new("L", (1, S), 0)
    for y in range(max(y0, 0), min(y1, S)):
        column.putpixel((0, y), round(start + (end - start) * (y - y0) / max(y1 - y0, 1)))
    return column.resize((S, S))


def glass(image: Image.Image) -> Image.Image:
    box = panel_box()
    x0, y0, x1, y1 = box
    shape = rounded_mask(box, PANEL_RADIUS)

    # 그림자: 유리판 아래로 살짝
    shadow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(shadow).rounded_rectangle([x0, y0 + px(26), x1, y1 + px(26)], radius=px(PANEL_RADIUS), fill=110)
    shadow = shadow.filter(ImageFilter.GaussianBlur(px(40)))
    image.paste(Image.new("RGB", (S, S), (0, 0, 0)), (0, 0), shadow)

    # 유리: 뒤를 크게 흐린 뒤 흰빛을 얹는다 (frost white + ultraThinMaterial)
    frosted = image.filter(ImageFilter.GaussianBlur(px(60)))
    frosted = Image.blend(frosted, Image.new("RGB", (S, S), INK), 0.10)
    image.paste(frosted, (0, 0), shape)

    # 위쪽 광택: 유리판 위 45%에 옅은 흰빛
    sheen = ImageChops.multiply(shape, vertical_fade(y0, y0 + int((y1 - y0) * 0.45), 24, 0))
    image.paste(Image.new("RGB", (S, S), INK), (0, 0), sheen)

    # 테두리: 위 밝게 → 아래 옅게 (frostHighlightTop → Bottom)
    edge = ImageChops.subtract(shape, rounded_mask(box, PANEL_RADIUS, inset=3))
    image.paste(Image.new("RGB", (S, S), INK), (0, 0), ImageChops.multiply(edge, vertical_fade(y0, y1, 150, 36)))
    return image


def stroke(draw: ImageDraw.ImageDraw, points: list, width: float, color: tuple) -> None:
    """둥근 끝·둥근 꺾임 선"""
    scaled = [(px(x), px(y)) for x, y in points]
    draw.line(scaled, fill=color, width=px(width), joint="curve")
    r = width / 2
    for x, y in points:
        draw.ellipse([px(x - r), px(y - r), px(x + r), px(y + r)], fill=color)


def accent_glow(image: Image.Image, center: tuple, radius: float) -> None:
    blob(image, ACCENT, center, radius, 90, radius * 0.6)


def monogram_ma(image: Image.Image) -> None:
    """기하 "Ma": M은 ink 선, a(원 + 기둥)는 accent"""
    weight = 48
    top, bottom = 392, 632
    m_left, m_right = 315, 505
    m_mid = ((m_left + m_right) / 2, 548)
    a_cx, a_cy, a_r = 645, 568, 64  # a_r: 고리 선 가운데 반지름. M과 a 사이는 획 굵기의 절반쯤 띄운다

    accent_glow(image, (a_cx, a_cy), 120)
    draw = ImageDraw.Draw(image)
    stroke(draw, [(m_left, bottom), (m_left, top), m_mid, (m_right, top), (m_right, bottom)], weight, INK)

    # a: 고리 + 오른쪽 기둥
    outer = a_r + weight / 2
    inner = a_r - weight / 2
    ring = Image.new("L", (S, S), 0)
    ring_draw = ImageDraw.Draw(ring)
    ring_draw.ellipse([px(a_cx - outer), px(a_cy - outer), px(a_cx + outer), px(a_cy + outer)], fill=255)
    ring_draw.ellipse([px(a_cx - inner), px(a_cy - inner), px(a_cx + inner), px(a_cy + inner)], fill=0)
    image.paste(Image.new("RGB", (S, S), ACCENT), (0, 0), ring)
    stem_x = a_cx + a_r
    stroke(draw, [(stem_x, a_cy - a_r), (stem_x, bottom)], weight, ACCENT)


def monogram_hangul(image: Image.Image) -> None:
    """"마": ㅁ은 도면 칸(ink), ㅏ는 세로선 + 눈금 가로획, 끝의 accent 점 = 이번 마디"""
    weight = 50
    draw = ImageDraw.Draw(image)
    left, right, top, bottom = 296, 500, 410, 614
    # ㅁ: 둥근 모서리 사각 고리
    ring = Image.new("L", (S, S), 0)
    ring_draw = ImageDraw.Draw(ring)
    # 모서리를 거의 각지게 둬야 ㅇ(아)으로 읽히지 않는다
    ring_draw.rounded_rectangle([px(left), px(top), px(right), px(bottom)], radius=px(16), fill=255)
    ring_draw.rounded_rectangle(
        [px(left + weight), px(top + weight), px(right - weight), px(bottom - weight)], radius=px(3), fill=0
    )
    image.paste(Image.new("RGB", (S, S), INK), (0, 0), ring)
    # ㅏ
    stem_x = 600
    stroke(draw, [(stem_x, 370), (stem_x, 654)], weight, INK)
    tick_y = 512
    stroke(draw, [(stem_x, tick_y), (676, tick_y)], weight * 0.8, INK)
    accent_glow(image, (712, tick_y), 90)
    draw = ImageDraw.Draw(image)
    draw.ellipse([px(712 - 34), px(tick_y - 34), px(712 + 34), px(tick_y + 34)], fill=ACCENT)


VARIANTS = {"ma": monogram_ma, "hangul": monogram_hangul}


def main() -> None:
    variant = sys.argv[1] if len(sys.argv) > 1 else "ma"
    out = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else OUT
    image = glass(background())
    VARIANTS[variant](image)
    image = image.resize((SIZE, SIZE), Image.LANCZOS)
    out.parent.mkdir(parents=True, exist_ok=True)
    image.save(out, "PNG", optimize=True)
    print(f"wrote {out} {image.size} {image.mode} ({variant})")


if __name__ == "__main__":
    main()
