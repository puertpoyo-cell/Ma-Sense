# AGENTS.md — 마선생 Masense

Claude Code 말고 다른 코딩 에이전트(Antigravity 등)가 이 저장소에서 일할 때 먼저 읽는 파일입니다.
규칙의 원본은 `CLAUDE.md`이고, 사양은 `docs/` 아래 문서입니다. 둘을 먼저 읽고 시작합니다.

## 꼭 지킬 것 (요약, 자세한 건 CLAUDE.md·docs/COMPLIANCE.md)

- 전문의약품 상표명을 코드·문구·문서 어디에도 쓰지 않습니다. 일반 표현(`GLP1`, 주 1회 주사)만
- 용량 추천, 증량·감량 시점, 단계(Lv) 표기, 칼로리·목표 체중, 랭킹·스트릭 보상, 커뮤니티를 만들지 않습니다
- 체중 결과에 칭찬·평가·질책을 하지 않습니다. 느낌표·이모지 금지. 건강 안내는 "의사와 상의하세요"로 끝냅니다
- 빨강·초록으로 좋고 나쁨을 표시하지 않습니다
- 문구는 `Masense/Resources/Localizable.xcstrings`에 두고 뷰에 하드코딩하지 않습니다
- `Rules/`는 Foundation만, 모든 규칙에 Swift Testing 단위 테스트
- 서드파티 패키지, 새 권한, 스키마 변경은 사람 확인 먼저. CloudKit 운영 스키마라 모델은 추가만
- 커밋 전 `python3 scripts/compliance_check.py` 통과

## 검토만 할 때

코드를 바꾸지 말고 제안을 `docs/REVIEW_<도구 이름>_<날짜>.md`에 적습니다. 커밋·푸시는 사람에게 묻고 합니다.
main에는 Claude Code도 직접 푸시하므로, 푸시 전에 `git pull origin main`.
