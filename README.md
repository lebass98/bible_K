# 열린성경 (YeollinBible)

맥에서 성경을 읽고, 찾고, 표시하고, 통독하는 **오픈소스 macOS 성경 앱** (MIT).
갓피플성경 26.13의 기능을 분석해서([분석 문서](docs/갓피플성경-분석.md)) 공개된 macOS API와 자유롭게 쓸 수 있는 성경 데이터로 처음부터 새로 만들었습니다.
갓피플성경의 코드·본문 데이터·그림·글꼴·문구·이름을 쓰지 않았고, 갓피플과는 관계가 없습니다.

현재 버전: **1.0** · 요구 사항: macOS 14 이상, Apple Silicon

## 기능

| 묶음 | 할 수 있는 일 |
|---|---|
| 성경 읽기 | 책·장 고르기(구약/신약 격자), 이전·다음 장(⌘← ⌘→), **구절로 바로 가기**(⌘L, `요3:16`·`요한복음 3장 16절`·`시 23`·`John 3:16`), 소제목·절 번호 보기, 명조/고딕·글자 크기·줄 간격 |
| 대역 | 두 역본을 나란히 (⌘D). 역본마다 절 번호가 달라도 맞춰서 보여 줌 |
| 원어 | KJV·WEB 낱말에 붙은 원어 번호(Strong's) 표시, 낱말을 누르면 히브리어·헬라어 원어·발음·뜻 (사전 14,197개) |
| 관주 | 고른 절과 연결된 구절을 추천 많은 순으로 (21만여 개), 누르면 그 구절로 이동 |
| 찾기 | 낱말 찾기(⌘F), **띄어쓰기가 달라도** 찾음, 여러 낱말 모두 들어간 절, 성경 전체·구약·신약·지금 책, 책별 개수 |
| 내 기록 | 형광펜 5색, 책갈피, 여러 절에 노트, 읽은 기록(날짜별) |
| 고른 절 | 클릭으로 고르기(Shift-클릭으로 범위), 아래 막대에서 형광펜·책갈피·노트·복사·카드·듣기, 오른쪽 클릭 메뉴 |
| 통독 | 계획 5가지(1년 통독, 구약·신약 함께 1년, 90일, 신약 90일, 시편·잠언 한 달) — **절 수로 재서 날마다 양을 고르게 나눔**, 날짜별 체크, 밀린 날, 매일 알림 |
| 오늘의 말씀 | 날마다 바뀌는 구절 235개, 지난날·다음날 보기, 복사·카드·책갈피, 매일 알림 |
| 말씀 카드 | 고른 구절을 그림으로 — 배경 10가지, 정사각형·세로·스토리 크기, 글자 크기, PNG 저장·복사 |
| 소리 내어 읽기 | 맥 내장 음성으로 한 절씩 읽고 읽는 절을 표시·따라 스크롤, 빠르기, 다음 장 이어 읽기 |
| 한 줄 감사 | 날마다 감사 한 줄 일기, 날짜별 목록, 오늘의 질문 |
| 역본 관리 | **내가 가진 성경 파일 가져오기** — USFM(파일·폴더·zip), JSON, 한 줄에 한 절인 글 파일(CSV·TSV·`창 1:1 …`), EUC-KR 한글 파일도 읽음 |
| 백업 | 책갈피·형광펜·노트·감사·통독 기록을 JSON 파일 하나로 내보내기·가져오기 |

### 들어 있는 역본

| 역본 | 출처 | 이용 조건 |
|---|---|---|
| 한글 성경 (공개본) | eBible.org `kor` (Korean Bible 1910, 개역 계열 본문) | 퍼블릭 도메인 |
| King James Version (원어 번호 포함) | eBible.org `eng-kjv2006` | 퍼블릭 도메인 |
| World English Bible (원어 번호 포함) | eBible.org `engwebp` | 퍼블릭 도메인 |

한글 공개본은 원본 데이터에 일부가 빠져 있습니다(시편 118:10–29, 골로새서 4:10–18, 베드로전서 4:15–5:14 등 약 110절). 빠진 장에서는 안내가 뜨니 대역으로 함께 보세요.

**개역개정·새번역·쉬운성경·NIV·ESV 등은 저작권이 있어서 넣지 않았습니다.** 사용 허락을 받은 파일이 있으면 "역본 관리 → 파일 가져오기"로 넣어 읽을 수 있고, 가져온 본문은 내 Mac(`~/Library/Application Support/YeollinBible/imported.sqlite`)에만 저장됩니다.

### 갓피플성경에는 있지만 없는 것

개역개정 등 저작권 역본 본문, 오디오 성경(사람이 녹음한 낭독), 로그인·서버 동기화(대신 백업 파일), 갓피플 소식·스토어·기도 나눔, 사도신경 등 신앙고백문, iPhone·iPad 버전.

## 설치

1. `./make_pkg.sh`로 만든 `dist/YeollinBible-<버전>.pkg`를 더블클릭
   - 인터넷에서 받은 파일은 "확인되지 않은 개발자" 경고가 뜰 수 있음 → 우클릭 → 열기
2. 설치하면 `/Applications/YeollinBible.app`(이름: 열린성경)에 들어가고 자동 실행

```bash
sudo installer -pkg dist/YeollinBible-1.0.pkg -target /
```

## 빌드

요구 사항: macOS 14 이상, Xcode 또는 Command Line Tools (Swift 6)

```bash
./scripts/make_database.sh   # 공개 데이터를 내려받아 Resources/bible.sqlite 만들기 (처음 한 번)
./build.sh                   # 테스트용: ~/Applications에 만들고 바로 실행
./make_pkg.sh                # 설치 파일 → dist/
swift test --scratch-path ~/Library/Caches/YeollinBible-build   # 단위 테스트
```

- 버전은 `Info.plist`의 `CFBundleShortVersionString`에서 바꿈
- `Resources/bible.sqlite`(약 43MB)는 저장소에 들어 있어서 보통은 다시 만들 필요 없음
- 외장하드(exFAT)에서는 테스트 실행 파일 서명이 안 돼서 `--scratch-path`로 내장 디스크에 빌드함

### 코드 구조

```
Sources/BibleCore/      성경 66권 정보, 구절 주소 읽기, USFM·JSON·글 파일 읽기, SQLite DB
Sources/BibleBuilder/   공개 데이터로 bible.sqlite 만드는 도구
Sources/YeollinBible/   SwiftUI 앱 (읽기·찾기·기록·통독·오늘의 말씀·감사·카드·역본 관리)
Tests/BibleCoreTests/   파서 테스트
docs/                   갓피플성경 분석 문서
```

문제 확인용 기록: `~/Library/Logs/YeollinBible.log`
내 기록 파일: `~/Library/Application Support/YeollinBible/userdata.json`

## 라이선스

- 코드: MIT ([LICENSE](LICENSE))
- 데이터: 역본은 퍼블릭 도메인, 원어 사전은 OpenScriptures Strong's Dictionary(CC BY-SA), 관주는 OpenBible.info(CC BY) — [DATA_LICENSES.md](DATA_LICENSES.md)

## 변경 기록

### 2026-10-25
- **1.0** 첫 버전
