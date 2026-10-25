#!/bin/bash
# 공개 데이터를 내려받아 Resources/bible.sqlite 만들기
#   한글 성경·KJV·WEB: eBible.org (퍼블릭 도메인)
#   원어 사전: OpenScriptures Strong's (CC BY-SA)
#   관주: OpenBible.info (CC BY)
set -euo pipefail
cd "$(dirname "$0")/.."

RAW="$HOME/Library/Caches/YeollinBible-data"
mkdir -p "$RAW"
cd "$RAW"

echo "▶ 자료 내려받는 중 → $RAW"
for id in kor eng-kjv2006 engwebp; do
    curl -sSfL -o "${id}_usfm.zip" "https://ebible.org/Scriptures/${id}_usfm.zip"
    rm -rf "$id" && mkdir "$id" && unzip -oq "${id}_usfm.zip" -d "$id"
done
curl -sSfL -o strongs-hebrew.js https://raw.githubusercontent.com/openscriptures/strongs/master/hebrew/strongs-hebrew-dictionary.js
curl -sSfL -o strongs-greek.js https://raw.githubusercontent.com/openscriptures/strongs/master/greek/strongs-greek-dictionary.js
curl -sSfL -o cross-references.zip https://a.openbible.info/data/cross-references.zip
rm -rf xref && mkdir xref && unzip -oq cross-references.zip -d xref

cd - >/dev/null
echo "▶ DB 만드는 중"
swift build -c release --product BibleBuilder
.build/release/BibleBuilder "$RAW" Resources/bible.sqlite
