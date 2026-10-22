"""앱 아이콘: 단색 바탕 위 유리 모노그램 (DESIGN_SYSTEM.md 6). Pillow 필요.

- `rings` (기본, 2026-10-22 참고 이미지 방향): 한 색조 바탕 + 반투명 동심원 원판 3겹(한 주씩 반복되는 마디의 리듬)
  + 그 위 밝은 반유리 캡슐 막대 4개로 세운 "M" (위는 거의 흰빛, 아래로 갈수록 투명). 막대마다 그림자를 둬 겹침이 보인다
- 아래 나머지 안은 midnight 단색 바탕. 마크 자체가 유리(글래스모피즘)다
- 마크 뒤에 accent → 인디고 구(球) 하나가 있고, 유리 마크가 그 위에 겹쳐 흐릿하게 비친다 = 이번 마디
- 유리 마크: 뒤를 흐리게 비치는 반투명 채움 + 위가 밝고 아래로 옅어지는 테두리 + 위쪽 광택 + 옅은 그림자 (FrostCard와 같은 재질)
- 모노그램은 앱 이름(마선생 / Masense)에서만 가져온다. 의약품 상표·로고를 연상시키는 형태·색·서체는 쓰지 않는다 (COMPLIANCE.md 2.1-2)
  - `m4` (기본): 캡슐형 유리 막대 4개를 겹쳐 세운 "M". 막대마다 유리를 따로 얹어 겹친 곳이 더 밝다
    주사기·알약 형상 금지(DESIGN_SYSTEM.md 6): 막대는 단색, 두 색 나눔·가운데 이음선 같은 알약 표현 없음
  - `ma`: 기하 도형 "Ma" 한 장 유리
  - `hangul`: "마" (ㅁ = 도면 칸, ㅏ의 가로획 = 자의 눈금)
- 글꼴 파일 없이 선·원으로 그린다

출력: Masense/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png (1024×1024, RGB, 알파 없음)
실행: python3 scripts/make_app_icon.py [rings|rings-midnight|m4|ma|hangul] [출력 경로]
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
INDIGO = (0x4F, 0x6B, 0xE8)


def px(value: float) -> int:
    return round(value * SCALE)


def new_mask() -> Image.Image:
    return Image.new("L", (S, S), 0)


def round_stroke(draw: ImageDraw.ImageDraw, points: list, width: float) -> None:
    """둥근 끝·둥근 꺾임 선 (마스크에 255로)"""
    draw.line([(px(x), px(y)) for x, y in points], fill=255, width=px(width), joint="curve")
    r = width / 2
    for x, y in points:
        draw.ellipse([px(x - r), px(y - r), px(x + r), px(y + r)], fill=255)


def ring(draw: ImageDraw.ImageDraw, center: tuple, radius: float, width: float) -> None:
    cx, cy = center
    outer, inner = radius + width / 2, radius - width / 2
    draw.ellipse([px(cx - outer), px(cy - outer), px(cx + outer), px(cy + outer)], fill=255)
    draw.ellipse([px(cx - inner), px(cy - inner), px(cx + inner), px(cy + inner)], fill=0)


# MARK: 모노그램 유리 조각 마스크(뒤에서 앞 순서)와 뒤에 둘 구 (중심, 반지름)

def capsule(start: tuple, end: tuple, width: float) -> Image.Image:
    mask = new_mask()
    round_stroke(ImageDraw.Draw(mask), [start, end], width)
    return mask


def glyph_m4() -> tuple:
    width = 104
    left, right, top, bottom = 300, 724, 330, 700
    valley = (512, 590)
    pieces = [
        capsule((left, top), (left, bottom), width),
        capsule((right, top), (right, bottom), width),
        capsule((left, top), valley, width),
        capsule((right, top), valley, width),
    ]
    return pieces, (606, 404), 196


def glyph_ma() -> tuple:
    weight = 88
    mask = new_mask()
    draw = ImageDraw.Draw(mask)
    top, bottom = 372, 640
    m_left, m_right = 262, 498
    m_mid = ((m_left + m_right) / 2, 548)
    round_stroke(draw, [(m_left, bottom), (m_left, top), m_mid, (m_right, top), (m_right, bottom)], weight)
    # a: 고리 + 오른쪽 기둥. M과 사이는 띄운다
    a_center, a_r = (672, 562), 78
    ring(draw, a_center, a_r, weight)
    stem_x = a_center[0] + a_r
    round_stroke(draw, [(stem_x, a_center[1] - a_r), (stem_x, bottom)], weight)
    return [mask], (700, 470), 190


def glyph_hangul() -> tuple:
    weight = 88
    mask = new_mask()
    draw = ImageDraw.Draw(mask)
    # ㅁ: 모서리를 거의 각지게 둬야 ㅇ(아)으로 읽히지 않는다
    left, right, top, bottom = 262, 520, 382, 640
    draw.rounded_rectangle([px(left), px(top), px(right), px(bottom)], radius=px(26), fill=255)
    draw.rounded_rectangle(
        [px(left + weight), px(top + weight), px(right - weight), px(bottom - weight)], radius=px(4), fill=0
    )
    # ㅏ
    stem_x = 650
    round_stroke(draw, [(stem_x, 330), (stem_x, 694)], weight)
    round_stroke(draw, [(stem_x, 512), (770, 512)], weight * 0.8)
    return [mask], (770, 440), 170


VARIANTS = {"m4": glyph_m4, "ma": glyph_ma, "hangul": glyph_hangul}

# rings 안의 바탕: accent 계열 파랑 한 색조, 위가 조금 밝다
RINGS_TOP = (0x5A, 0x7B, 0xF0)
RINGS_BOTTOM = (0x33, 0x45, 0xC2)
RINGS_SHADOW = (0x14, 0x1E, 0x66)


# MARK: 재질

def orb(center: tuple, radius: float) -> tuple:
    """accent(좌상) → 인디고(우하) 그라데이션 구. (레이어, 마스크)"""
    cx, cy = center
    side = px(radius * 2)
    gradient = Image.linear_gradient("L").rotate(-45).resize((side, side))
    colored = Image.composite(Image.new("RGB", (side, side), INDIGO), Image.new("RGB", (side, side), ACCENT), gradient)
    layer = Image.new("RGB", (S, S), MIDNIGHT)
    box = [px(cx - radius), px(cy - radius)]
    layer.paste(colored, (box[0], box[1]))
    mask = new_mask()
    ImageDraw.Draw(mask).ellipse([box[0], box[1], box[0] + side, box[1] + side], fill=255)
    return layer, mask


def vertical_fade(y0: int, y1: int, start: int, end: int) -> Image.Image:
    """y0에서 start, y1에서 end로 바뀌는 세로 그라데이션 (그 밖은 0)"""
    column = Image.new("L", (1, S), 0)
    for y in range(max(y0, 0), min(y1, S)):
        column.putpixel((0, y), round(start + (end - start) * (y - y0) / max(y1 - y0, 1)))
    return column.resize((S, S))


def glass_piece(image: Image.Image, piece: Image.Image) -> None:
    """유리 조각 하나를 지금 그림 위에 얹는다. 뒤에 그려진 것(구, 앞선 조각)을 흐리게 비친다"""
    # 그림자
    shadow = ImageChops.offset(piece, 0, px(16)).filter(ImageFilter.GaussianBlur(px(20)))
    image.paste(Image.new("RGB", (S, S), (0, 0, 0)), (0, 0), shadow.point(lambda v: int(v * 0.40)))

    # 채움: 뒤를 크게 흐린 뒤 흰빛을 얹는다
    frosted = image.filter(ImageFilter.GaussianBlur(px(30)))
    frosted = Image.blend(frosted, Image.new("RGB", (S, S), INK), 0.20)
    image.paste(frosted, (0, 0), piece)

    # 위쪽 광택
    _, y0, _, y1 = piece.getbbox()
    sheen = ImageChops.multiply(piece, vertical_fade(y0, y0 + (y1 - y0) // 2, 46, 0))
    image.paste(Image.new("RGB", (S, S), INK), (0, 0), sheen)

    # 테두리: 위 밝게 → 아래 옅게
    edge = ImageChops.subtract(piece, piece.filter(ImageFilter.MinFilter(px(3) * 2 + 1)))
    image.paste(Image.new("RGB", (S, S), INK), (0, 0), ImageChops.multiply(edge, vertical_fade(y0, y1, 230, 80)))


def render(variant: str) -> Image.Image:
    pieces, orb_center, orb_radius = VARIANTS[variant]()
    image = Image.new("RGB", (S, S), MIDNIGHT)

    # 뒤의 구 (이번 마디)
    orb_layer, orb_mask = orb(orb_center, orb_radius)
    image.paste(orb_layer, (0, 0), orb_mask)

    for piece in pieces:
        glass_piece(image, piece)
    return image.resize((SIZE, SIZE), Image.LANCZOS)


def gradient_background(top: tuple, bottom: tuple) -> Image.Image:
    fade = vertical_fade(0, S, 0, 255)
    return Image.composite(Image.new("RGB", (S, S), bottom), Image.new("RGB", (S, S), top), fade)


def soft_shadow(image: Image.Image, mask: Image.Image, color: tuple, offset: float, blur: float, strength: float) -> None:
    shadow = ImageChops.offset(mask, 0, px(offset)).filter(ImageFilter.GaussianBlur(px(blur)))
    image.paste(Image.new("RGB", (S, S), color), (0, 0), shadow.point(lambda v: int(v * strength)))


def disc(radius: float) -> Image.Image:
    mask = new_mask()
    c = SIZE / 2
    ImageDraw.Draw(mask).ellipse([px(c - radius), px(c - radius), px(c + radius), px(c + radius)], fill=255)
    return mask


def render_rings(midnight: bool = False) -> Image.Image:
    if midnight:
        image, shadow_color = Image.new("RGB", (S, S), MIDNIGHT), (0, 0, 0)
    else:
        image, shadow_color = gradient_background(RINGS_TOP, RINGS_BOTTOM), RINGS_SHADOW

    # 동심원 원판 3겹: 안쪽일수록 밝다. 원판마다 옅은 그림자와 위가 밝은 테두리
    for radius, alpha in [(400, 0.11), (304, 0.14), (208, 0.18)]:
        mask = disc(radius)
        soft_shadow(image, mask, shadow_color, 8, 18, 0.18)
        image.paste(Image.new("RGB", (S, S), INK), (0, 0), mask.point(lambda v: int(v * alpha)))
        edge = ImageChops.subtract(mask, mask.filter(ImageFilter.MinFilter(px(2) * 2 + 1)))
        _, y0, _, y1 = mask.getbbox()
        image.paste(Image.new("RGB", (S, S), INK), (0, 0), ImageChops.multiply(edge, vertical_fade(y0, y1, 90, 10)))

    # 반유리 막대 4개 M: 뒤를 살짝 흐리게 비치고, 위는 흰빛 92% → 아래 60%
    width = 96
    left, right, top, bottom = 322, 702, 352, 676
    valley = (512, 590)
    pieces = [
        capsule((left, top), (left, bottom), width),
        capsule((right, top), (right, bottom), width),
        capsule((left, top), valley, width),
        capsule((right, top), valley, width),
    ]
    _, m_top, _, m_bottom = pieces[0].getbbox()
    for piece in pieces:
        soft_shadow(image, piece, shadow_color, 12, 16, 0.38)
        image.paste(image.filter(ImageFilter.GaussianBlur(px(18))), (0, 0), piece)
        white = ImageChops.multiply(piece, vertical_fade(m_top, m_bottom, 235, 150))
        image.paste(Image.new("RGB", (S, S), INK), (0, 0), white)
    return image.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> None:
    variant = sys.argv[1] if len(sys.argv) > 1 else "rings"
    out = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else OUT
    if variant.startswith("rings"):
        image = render_rings(midnight=variant == "rings-midnight")
    else:
        image = render(variant)
    out.parent.mkdir(parents=True, exist_ok=True)
    image.save(out, "PNG", optimize=True)
    print(f"wrote {out} {image.size} {image.mode} ({variant})")


if __name__ == "__main__":
    main()
