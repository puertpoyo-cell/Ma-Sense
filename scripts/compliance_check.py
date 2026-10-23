#!/usr/bin/env python3
"""COMPLIANCE.md 2.1 금지선과 톤 규칙을 코드·문구에서 자동 점검한다.

사용: python3 scripts/compliance_check.py   (저장소 루트에서)
위반이 있으면 목록을 출력하고 종료 코드 1. CI에서 푸시마다 실행한다.

이 파일 자체는 금지어 목록을 담고 있으므로 검사 대상에서 뺀다.
"""

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
# 화면 문구(Localizable)와 권한 요청 문구(InfoPlist) 카탈로그, 위젯 확장 문구 (D6)
CATALOGS = sorted((ROOT / "Masense" / "Resources").glob("*.xcstrings")) + sorted((ROOT / "MasenseWidgets").glob("*.xcstrings"))
CODE_DIRS = [ROOT / "Masense", ROOT / "MasenseTests", ROOT / "MasenseWidgets", ROOT / "Shared"]
DOC_DIRS = [ROOT / "docs"]

# 2.1-2 특정 약물명·상표명·성분명 (코드 식별자·주석·문구·문서 전부)
DRUG_NAMES = [
    "위고비", "마운자로", "삭센다", "오젬픽", "젭바운드", "리벨서스", "트루리시티", "빅토자",
    "세마글루타이드", "티르제파타이드", "리라글루타이드", "둘라글루타이드",
    "wegovy", "mounjaro", "saxenda", "ozempic", "zepbound", "rybelsus", "trulicity", "victoza",
    "semaglutide", "tirzepatide", "liraglutide", "dulaglutide",
]

# 사용자 노출 문구(한국어)에 쓰지 않는 표현
FORBIDDEN_KO = {
    "용량": "2.1-1 용량 표현 (메모 필드일 뿐)",
    "증량": "2.1-1 증량 제안",
    "다음 단계": "2.1-1 다음 단계",
    "목표 체중": "2.1-3 목표 체중",
    "목표까지": "2.1-3 목표까지 n kg",
    "칼로리": "2.1-3 칼로리 목표",
    "랭킹": "2.1-4 랭킹",
    "연속": "2.1-4 스트릭",
    "배지": "2.1-4 배지",
    "건너뜀": "R10 끼니를 비워도 건너뜀이라 쓰지 않음",
    # 3.1 판단어 (단백질 목표 "채웠습니다"만 허용)
    "좋음": "3.1 판단어", "나쁨": "3.1 판단어", "잘함": "3.1 판단어", "잘했": "3.1 판단어",
    "부족": "3.1 판단어", "충분": "3.1 판단어", "성공": "3.1 판단어", "실패": "3.1 판단어",
    "달성": "3.1 판단어", "축하": "6. 축하 없음",
    # 2.2 BMI는 숫자만. 구간 이름으로 판단하지 않는다 (D5)
    "저체중": "2.2 BMI 구간 이름", "과체중": "2.2 BMI 구간 이름", "정상 체중": "2.2 BMI 구간 이름",
    "비만 전단계": "2.2 BMI 구간 이름", "비만 1단계": "2.2 BMI 구간 이름", "비만 2단계": "2.2 BMI 구간 이름",
    "비만 3단계": "2.2 BMI 구간 이름", "고도비만": "2.2 BMI 구간 이름", "고도 비만": "2.2 BMI 구간 이름",
}

# 알림 문구(잠금화면 노출)에 쓰지 않는 단어 (3.3)
NOTIFICATION_FORBIDDEN = ["주사"]

# 코드에서 쓰지 않는 색·아이콘 (DESIGN_SYSTEM.md 1, 7)
CODE_PATTERNS = {
    r"Color\.red\b|Color\.green\b|\.foregroundStyle\(\.red\)|\.foregroundStyle\(\.green\)|\.tint\(\.red\)|\.tint\(\.green\)|systemRed|systemGreen": "빨강·초록 금지",
    r"role:\s*\.destructive": "destructive 역할은 빨강으로 그려진다",
    r"\"syringe": "주사기 아이콘 금지",
    r"\"pills": "알약 아이콘 금지",
    r"\"scalemass": "체중계 아이콘 금지",
    r"exclamationmark\.triangle": "경고 삼각형 금지 (NoticeLine은 info.circle)",
}

EMOJI = re.compile("[\U0001F300-\U0001FAFF☀-➿⭐✅]")


def catalog_values():
    for catalog in CATALOGS:
        data = json.loads(catalog.read_text(encoding="utf-8"))
        for key, entry in data["strings"].items():
            for lang, loc in entry.get("localizations", {}).items():
                unit = loc.get("stringUnit")
                if unit:
                    yield key, lang, unit["value"]


def main() -> int:
    problems = []

    for key, lang, value in catalog_values():
        if "!" in value or "！" in value:
            problems.append(f"[문구] {key} ({lang}) 느낌표: {value}")
        if EMOJI.search(value):
            problems.append(f"[문구] {key} ({lang}) 이모지: {value}")
        if lang == "ko":
            for word, reason in FORBIDDEN_KO.items():
                if word in value:
                    problems.append(f"[문구] {key} '{word}' — {reason}: {value}")
            # 알림과 위젯(잠금화면에도 놓인다)
            if key.startswith(("notif.", "widget.", "activity.")):
                for word in NOTIFICATION_FORBIDDEN:
                    if word in value:
                        problems.append(f"[알림] {key} '{word}' — 3.3 잠금화면 민감어: {value}")

    files = [p for d in CODE_DIRS for p in d.rglob("*") if p.suffix in {".swift", ".xcstrings"}]
    files += [p for d in DOC_DIRS for p in d.rglob("*") if p.suffix in {".md", ".html"}]
    files.append(ROOT / "CLAUDE.md")
    # 앱 이름·권한 요청 문구가 빌드 설정(INFOPLIST_KEY_*)에 있다
    files.append(ROOT / "Masense.xcodeproj" / "project.pbxproj")
    for path in files:
        text = path.read_text(encoding="utf-8")
        lower = text.lower()
        rel = path.relative_to(ROOT)
        for name in DRUG_NAMES:
            if name in lower:
                problems.append(f"[약물명] {rel}: '{name}' — 2.1-2")
        if path.suffix == ".swift":
            for pattern, reason in CODE_PATTERNS.items():
                for match in re.finditer(pattern, text):
                    line = text.count("\n", 0, match.start()) + 1
                    problems.append(f"[코드] {rel}:{line} {reason}")

    if problems:
        print(f"금지선 위반 {len(problems)}건")
        for problem in problems:
            print("  " + problem)
        return 1
    print(f"금지선 점검 통과 (문구 {sum(1 for _ in catalog_values())}개, 파일 {len(files)}개)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
