# mdwatch

Markdown + Mermaid 라이브 프리뷰 도구 (macOS 전용).

`.md` 파일을 브라우저로 열어 mermaid 다이어그램까지 렌더링하고, 파일 저장 시 변경된 부분만 자동 갱신합니다. 같은 파일을 다시 열면 기존 브라우저 탭으로 focus 합니다.

## 주요 특징

- **Mermaid 다이어그램 렌더링** — Warp/VS Code 기본 뷰어가 지원하지 않는 mermaid가 동작합니다.
- **저장 시 자동 리프레시** — SSE 기반 부분 업데이트, 스크롤 위치·테마 유지.
- **변경 줄 하이라이트** — 어디가 바뀌었는지 즉시 표시(3초 박스 → 영구 마커).
- **ECharts 차트 펜스 + embed 문법** — 코드 펜스로 인터랙티브 차트 삽입, 다른 파일 임베드, 공유용 단일 md flatten 내보내기.
- **이미지·정적 파일 서빙** — svg/img/css/js/pdf 등을 올바른 MIME으로 함께 서빙, 공유 변환 시 외부 svg 자동 인라인.
- **상시 daemon + URL 단위 즐겨찾기** — 한 번 실행하면 백그라운드 상주(~25 MB), 파일별 고유 URL이라 브라우저 북마크 가능.
- **같은 URL은 기존 탭 focus** — 두 번 열어도 탭이 늘어나지 않습니다.
- **다크/라이트 테마** — macOS 시스템 설정 자동 감지 + 수동 토글.
- **한글 코드블록 정렬** — D2Coding 폰트 스택으로 한글 혼용 ASCII 다이어그램이 일그러지지 않습니다 ([INSTALL.md 4-(4)](docs/INSTALL.md) 참조).

## 타 md 뷰어와의 차별점

live reload 계열 공개 도구는 여럿 있지만, **"저장 시점의 변경 줄 하이라이트"를 제공하는 스탠드얼론 뷰어는 mdwatch가 유일**합니다 (2026-07 조사 기준).

| | 실시간 반영 | 변경 줄 하이라이트 | Mermaid | 차트(ECharts) | 비고 |
|---|---|---|---|---|---|
| **mdwatch** | O (SSE 부분 갱신) | **O** (저장 시 diff → fade → 영구 마커) | O | O (펜스) | daemon·URL 즐겨찾기·탭 focus·한글 정렬 |
| [markserv](https://github.com/markserv/markserv) | O | X | X | X | Node, 2014년부터 유지, KaTeX |
| [grip](https://github.com/joeyespo/grip) | O (새로고침) | X | X | X | GitHub API 렌더링 — 인터넷 필수·시간당 60회 제한, 2023년 이후 방치 |
| [mdr](https://github.com/clevercloud/mdr) | O | X | O | X | Rust 단일 바이너리, 경량 |
| [Markdown Viewer (Chrome 확장)](https://chromewebstore.google.com/detail/markdown-viewer/ckkdlimhmcjmikdlpkmbgfkaikojcbjk) | O (자동 새로고침) | X | O | X | 서버 불필요, MathJax |
| VS Code 프리뷰 (+확장) | O | 부분적 — [Markdown Diff Preview](https://open-vsx.org/extension/batlounis/markdown-diff-preview)가 git diff 기준 하이라이트 | 확장 필요 | 확장 필요 (MPE 등) | 에디터 종속 |

mdwatch의 변경 하이라이트는 git 상태가 아니라 **저장 순간의 diff** 기준이라, 커밋 여부와 무관하게 "방금 뭐가 바뀌었는지"를 따라갈 수 있습니다. AI 에이전트가 문서를 수정하는 동안 브라우저로 지켜보는 워크플로우에 특히 유용합니다.

## 빠른 시작

```bash
# 0. Node.js 16+ 확인 (없으면 nodejs.org/Homebrew/nvm 중 택일 — INSTALL.md 참조)
node -v

# 1. 설치 (mdwatch.app 등록, alias 추가까지)
./src/install-mdwatch.command

# 2. .md 파일 기본 앱 설정 (Finder에서 .md 파일 → Cmd+I → Open with → mdwatch → Change All)

# 3. 사용
mdwatch ~/argo/some_file.md     # 터미널
# 또는 Finder에서 .md 더블클릭
```

> 첫 더블클릭 시 macOS가 "mdwatch가 [브라우저]를 제어하려고 합니다" 다이얼로그를 띄웁니다. **[허용]**을 누르세요 (탭 focus 기능에 필수).

## 문서

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
| 포트 | `localhost:7474` (고정, 변경 시 mdwatch.js 상단 `PORT` 수정) |
| 루트 디렉토리 | `~/argo` (변경 시 mdwatch.js 상단 `ROOT` 수정) |
