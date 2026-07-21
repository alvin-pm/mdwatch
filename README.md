# mdwatch

**AI와 함께 문서를 완성하기 위한 markdown 뷰어 — 외부 프로세스가 파일을 편집하는 걸 "관전"하고, 그 자리에서 고친다.**

Markdown은 **AI가 가장 싸게 쓰는 포맷**입니다. mdwatch는 그 markdown을 *사람이 읽기 좋게 렌더링*하고, *AI가 저장할 때마다 무엇이 바뀌었는지 즉시 보여주고*, *블록을 더블클릭해 바로 손보는* 얇은 레이어입니다 — **"AI가 쓰기 가장 싼 포맷 + 사람이 읽기 좋게 만드는 레이어"**.

`.md`를 브라우저로 열어 mermaid·수식·차트까지 렌더링하고, 파일이 저장되면 **변경된 줄만** 하이라이트하며 부분 갱신합니다(커밋 여부 무관, 저장 순간의 diff 기준). 같은 파일을 다시 열면 기존 탭으로 focus 합니다.

> **플랫폼**: macOS에서 개발·검증. Linux/Windows는 CLI(`mdwatch <file>`) 기준 best-effort로 동작하나 **탭 focus·시스템 테마 감지 등 일부 기능은 미보장**입니다.

## 주요 특징

**AI 협업 루프 (핵심)**

- **변경 줄 하이라이트** — 저장 순간의 diff 기준으로 어디가 바뀌었는지 즉시 표시(3초 박스 → 영구 마커). **AI가 문서를 고치는 동안 브라우저로 따라볼 수 있습니다.**
- **인라인 블록 편집** — 블록을 더블클릭해 소스를 즉석 수정(⌘↵ 저장). 그 블록만 국소 치환해 git diff를 해치지 않고, 편집 중 외부(AI) 수정과의 충돌은 안전하게 보존·해결. 상세: [FEATURES](docs/FEATURES.md#인라인-블록-편집) · [ARCHITECTURE](docs/ARCHITECTURE.md).
- **저장 시 자동 리프레시** — SSE 기반 부분 업데이트, 스크롤 위치·테마 유지.

**렌더링**

- **Mermaid 다이어그램** — Warp/VS Code 기본 뷰어가 지원하지 않는 mermaid가 동작합니다.
- **코드 syntax highlighting** — highlight.js, 언어 명시 펜스만 (ASCII 다이어그램은 평문 보호). 다크/라이트 동기화.
- **KaTeX 블록 수식** — `$$...$$` / ` ```math ` 펜스 (인라인 `$`는 금액 표기 오탐 방지를 위해 미지원).
- **ECharts 차트 펜스 + embed 문법** — 코드 펜스로 인터랙티브 차트 삽입, 다른 파일 임베드, 공유용 단일 md flatten 내보내기.
- **목차(TOC) 패널** — 우상단 접이식, 클릭 스크롤 + 현재 위치 강조.
- **한글 코드블록 정렬** — 코드블록 폰트를 D2Coding(로컬→웹폰트)으로 통일해, 한글 혼용 다이어그램과 박스문자(`┌─│`)·화살표(`→↑`)가 일그러지지 않습니다. [다이어그램 가이드](docs/DIAGRAM-GUIDE.md) 참조.

**운영**

- **상시 daemon + URL 단위 즐겨찾기** — 한 번 실행하면 백그라운드 상주(~25 MB), 파일별 고유 URL이라 브라우저 북마크 가능.
- **같은 URL은 기존 탭 focus** (macOS) — 두 번 열어도 탭이 늘어나지 않습니다.
- **다크/라이트 테마** — 시스템 설정 자동 감지(macOS) + 수동 토글.
- **이미지·정적 파일 서빙** — svg/img/css/js/pdf 등을 올바른 MIME으로 함께 서빙, 공유 변환 시 외부 svg 자동 인라인.

## 타 md 뷰어와의 차별점

live reload 계열 공개 도구는 여럿 있지만, **저장 시점의 변경 줄 하이라이트 + 블록 인라인 편집을 한 스탠드얼론 뷰어로 묶은 조합은 드뭅니다** (2026-07 조사 기준). 대부분은 "미리보기"에 그치고, 편집은 별도 에디터로 넘어가야 합니다.

| | 실시간 반영 | 변경 줄 하이라이트 | Mermaid | 차트(ECharts) | 비고 |
|---|---|---|---|---|---|
| **mdwatch** | O (SSE 부분 갱신) | **O** (저장 시 diff → fade → 영구 마커) | O | O (펜스) | daemon·URL 즐겨찾기·탭 focus·한글 정렬·하이라이팅·KaTeX·TOC |
| [markserv](https://github.com/markserv/markserv) | O | X | X | X | Node, 2014년부터 유지, KaTeX |
| [grip](https://github.com/joeyespo/grip) | O (새로고침) | X | X | X | GitHub API 렌더링 — 인터넷 필수·시간당 60회 제한, 2023년 이후 방치 |
| [mdr](https://github.com/clevercloud/mdr) | O | X | O | X | Rust 단일 바이너리, 경량 |
| [Markdown Viewer (Chrome 확장)](https://chromewebstore.google.com/detail/markdown-viewer/ckkdlimhmcjmikdlpkmbgfkaikojcbjk) | O (자동 새로고침) | X | O | X | 서버 불필요, MathJax |
| VS Code 프리뷰 (+확장) | O | 부분적 — [Markdown Diff Preview](https://open-vsx.org/extension/batlounis/markdown-diff-preview)가 git diff 기준 하이라이트 | 확장 필요 | 확장 필요 (MPE 등) | 에디터 종속 |

mdwatch의 변경 하이라이트는 git 상태가 아니라 **저장 순간의 diff** 기준이라, 커밋 여부와 무관하게 "방금 뭐가 바뀌었는지"를 따라갈 수 있습니다. AI 에이전트가 문서를 수정하는 동안 브라우저로 지켜보는 워크플로우에 특히 유용합니다.

## 설치 · 실행

### 가장 빠르게 (설치 없이 — npx)

```bash
# 저장소에서 바로 실행 (Node.js 16+ 필요). 파일 열람 루트는 MDWATCH_ROOT로 지정.
MDWATCH_ROOT="$PWD" npx github:alvin-pm/mdwatch some_file.md
```

### Homebrew (macOS, tap)

```bash
brew install alvin-pm/mdwatch/mdwatch    # tap + 설치 (준비 예정 — packaging/homebrew 참조)
mdwatch some_file.md
```

### 소스에서 (macOS 풀 통합 — Finder 더블클릭·탭 focus)

```bash
node -v                          # Node.js 16+ 확인
./src/install-mdwatch.command    # mdwatch.app 등록 + alias
# .md 기본 앱 설정: Finder에서 .md → Cmd+I → Open with → mdwatch → Change All
mdwatch some_file.md             # 또는 Finder에서 더블클릭
```

> **경로 루트**: 열람 가능한 파일 루트는 `MDWATCH_ROOT`(기본 `~/argo` — 작성자 기본값). 다른 환경은 `MDWATCH_ROOT=<원하는 폴더>`로 지정하세요. 루트 밖 파일은 `?abs=` URL로 열립니다.
> **macOS 권한**: 첫 더블클릭 시 "mdwatch가 [브라우저]를 제어하려고 합니다" 다이얼로그가 뜹니다. **[허용]** — 탭 focus 기능에 필요합니다(거부해도 새 탭 open으로 폴백).

## 보안 · 신뢰 경계

mdwatch는 **로컬 개인 도구**입니다. 공개 서버가 아닙니다.

- daemon은 **`127.0.0.1`에만 바인딩** — 같은 머신에서만 접근.
- **`POST /__edit`(인라인 편집)로 파일을 씁니다** — `.md`/`.markdown` 파일만, 로컬 요청 전제. 신뢰할 수 없는 페이지가 이 daemon에 요청을 보낼 수 있는 환경(공용 머신 등)에서는 편집을 쓰지 마세요.
- **HTML sanitization 없음** — 인라인 `style`/HTML을 그대로 렌더(의도된 trade-off). 신뢰하는 문서만 여세요.

## 문서

- **[기능 데모](docs/DEMO.md)** — 하이라이팅·수식·다이어그램·차트·TOC를 한 파일에서 확인 (mdwatch로 열어보세요)
- **[ASCII 다이어그램 가이드](docs/DIAGRAM-GUIDE.md)** — 깨지지 않는 박스 그리는 규칙 + **AI 에이전트용 복붙 지시문**
- **[기능 상세](docs/FEATURES.md)** — 각 기능의 동작과 사용법
- **[아키텍처](docs/ARCHITECTURE.md)** — 전체 구조, 데이터 흐름, TCC 권한 모델
- **[설치 가이드](docs/INSTALL.md)** — 팀원 배포용 단계별 절차
- **[개발 가이드](docs/DEVELOPMENT.md)** — 향후 개선 시 어디를 손대야 하는지
- **[변경 이력](docs/CHANGELOG.md)** — 주요 변경 내역

## 디렉토리 구조

```
mdwatch_source/
├── README.md                 # 본 문서
├── docs/                     # 설계·개발·운영 문서
│   ├── ARCHITECTURE.md
│   ├── FEATURES.md
│   ├── INSTALL.md
│   ├── DEVELOPMENT.md
│   └── CHANGELOG.md
└── src/                      # 배포용 소스 원본
    ├── mdwatch.js            # Node 서버 + CLI (단일 파일, marked 인라인 번들)
    ├── main.applescript      # mdwatch.app 핸들러 (Finder 더블클릭용)
    └── install-mdwatch.command  # 자동 설치 스크립트
```

## 실행 환경

| 항목 | 값 |
|------|------|
| OS | macOS 12+ |
| Node.js | 16 이상 |
| 외부 의존성 | 없음 (marked는 mdwatch.js에 인라인 번들) |
| 권장 폰트 | D2Coding — 한글 코드블록/다이어그램 정렬용, 미설치 시 웹폰트 폴백 ([INSTALL.md](docs/INSTALL.md)) |
| 메모리 점유 | idle 25 MB / 파일 5개 동시 watch 30 MB |
| 포트 | `localhost:7474` (환경변수 `MDWATCH_PORT`로 변경 가능) |
| 루트 디렉토리 | `~/argo` (환경변수 `MDWATCH_ROOT`로 변경 가능) |

## 크레딧 (서드파티)

번들 포함:

- [marked](https://github.com/markedjs/marked) v15 (MIT, © Christopher Jeffrey) — mdwatch.js에 인라인 번들, 원 저작권 고지는 파일 헤더에 보존

브라우저가 CDN(jsDelivr·Google Fonts)에서 로드 (재배포 아님):

- [Mermaid](https://github.com/mermaid-js/mermaid) (MIT) — 다이어그램
- [highlight.js](https://github.com/highlightjs/highlight.js) (BSD-3-Clause) — 코드 하이라이팅
- [KaTeX](https://github.com/KaTeX/KaTeX) (MIT) — 수식
- [Apache ECharts](https://github.com/apache/echarts) (Apache-2.0) — 차트
- [D2Coding](https://github.com/naver/d2codingfont) (OFL-1.1, NAVER) — 한글 코딩 폰트. 로컬 설치본 우선, 미설치 시 [Joungkyun/font-d2coding](https://github.com/Joungkyun/font-d2coding) 미러의 woff2를 jsDelivr로 로드
- [Nanum Gothic Coding](https://fonts.google.com/specimen/Nanum+Gothic+Coding) (OFL-1.1) — 3차 폴백

## 개발자

- Alvin — <alvin@techtaka.com> / <alvin.j.chey@gmail.com>

라이선스: [MIT](LICENSE)
