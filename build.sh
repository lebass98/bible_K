#!/bin/bash
# YeollinBible 빌드 → ~/Applications/YeollinBible.app 생성
# (외장하드가 exFAT이라 앱 서명이 안 될 수 있어서, 앱은 내장 디스크에 만듦)
set -euo pipefail
cd "$(dirname "$0")"

echo "▶ 빌드 중..."
swift build -c release --product YeollinBible

APP="$HOME/Applications/YeollinBible.app"
echo "▶ 앱 묶는 중: $APP"
pkill -x YeollinBible 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/YeollinBible "$APP/Contents/MacOS/YeollinBible"
cp Info.plist "$APP/Contents/Info.plist"
# 브랜드 이미지를 앱 안에 포함 (시안 폴더에 의존하지 않음)
mkdir -p "$APP/Contents/Resources/Brand"
cp -X Resources/Brand/*.png "$APP/Contents/Resources/Brand/"
# 아이콘이 있을 때만 넣음 (scripts/make_icon.swift로 만듦)
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# 성경 DB (없으면 scripts/make_database.sh로 만듦)
[ -f Resources/bible.sqlite ] || { echo "Resources/bible.sqlite가 없어요. 먼저 ./scripts/make_database.sh 를 실행하세요." >&2; exit 1; }
cp -X Resources/bible.sqlite "$APP/Contents/Resources/bible.sqlite"

echo "▶ 서명 중 (내 Mac 전용)"
# 개인용 서명 (다시 빌드하면 macOS가 새 앱으로 보고 권한을 다시 요청함)
codesign --force --sign - "$APP"

echo "✅ 완료: $APP"

# 자동 실행 없이 패키징·서명만 확인할 때 사용
if [ "${1:-}" != "--no-open" ]; then
    echo "▶ 앱 실행"
    open "$APP"
fi
