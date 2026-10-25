# 데이터 출처와 이용 조건

`Resources/bible.sqlite`는 `scripts/make_database.sh`가 아래 데이터로 만든 파일입니다. 코드(MIT)와 이용 조건이 다릅니다.

| 데이터 | 출처 | 이용 조건 |
|---|---|---|
| 한글 성경 (공개본) | eBible.org — Korean Bible 1910 (`kor`) https://ebible.org/find/details.php?id=kor | 퍼블릭 도메인 |
| King James Version | eBible.org — `eng-kjv2006` https://ebible.org/find/details.php?id=eng-kjv2006 | 퍼블릭 도메인 |
| World English Bible | eBible.org — `engwebp` https://ebible.org/find/details.php?id=engwebp | 퍼블릭 도메인 |
| Strong's Hebrew/Greek Dictionary | OpenScriptures https://github.com/openscriptures/strongs | CC BY-SA (Copyright 2010, Open Scriptures) |
| Cross References | OpenBible.info https://www.openbible.info/labs/cross-references/ | CC BY |

바꾼 점
- 한글 성경: 따옴표(`` ` `` `'` → ‘ ’)와 느낌표·물음표 앞 띄어쓰기를 다듬음
- KJV: 문단 기호(¶)를 뺌
- 관주: 추천 3표 이상만 넣음
- 원어 사전 번호를 `H0430` → `H430` 꼴로 맞춤

오늘의 말씀 구절 목록, 통독 계획, 감사 질문 문구는 이 프로젝트에서 새로 만든 것입니다(MIT).
