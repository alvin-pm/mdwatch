# 기능 상세

## 렌더링

| 기능 | 동작 |
|------|------|
| Markdown → HTML | marked v15 (GFM 활성화) |
| Mermaid 다이어그램 | `mermaid@11` CDN, 브라우저 측 렌더링. 다크 테마 자동 적용 |
| 인라인 HTML | sanitization 없이 그대로 주입 (`style` 속성 포함 모두 동작) |
| 코드 블록 | 언어 명시 펜스는 highlight.js@11 CDN으로 syntax highlighting. 언어 없는 블록은 평문 유지 (ASCII 다이어그램 보호) |
| 수식 (KaTeX) | 단독 줄 `$$...$$` 블록 또는 ` ```math ` 펜스 → KaTeX 렌더링. 인라인 `$...$`는 미지원 ("$12K" 같은 금액 표기 오탐 방지) |
| ECharts 차트 | ` ```chart:echarts ` 펜스 → SVG 렌더러로 차트. spec은 각 div `data-spec`에 내장 (SSE 갱신 후에도 재초기화) |
| 목차 (TOC) | 헤딩 2개 이상이면 우상단 "☰ 목차" 버튼 → 접이식 패널 (h1-h4 계층, 클릭 스크롤, scroll-spy 현재 위치 강조, 표시 상태 localStorage 저장) |
| 테이블 | 첫 헤더가 비어있으면 첫 컬럼 10% 폭으로 자동 좁힘 (행 라벨용) |
| 이미지 | `max-width: 100%` |
| 줄 번호 gutter | 모든 블록에 `data-line` 속성 + 좌측 라인 번호 항상 표시 |

## 변경 감지 & 자동 갱신

| 단계 | 시간 | 동작 |
|------|------|------|
| 파일 저장 감지 | 즉시 | `fs.watch` 이벤트 발생 |
| Debounce | 150 ms | 연속 저장 이벤트 묶음 |
| diff 계산 | - | 앞/뒤 동일 부분 제외한 변경 줄만 산출 (단순 truncate 방식) |
| SSE 전송 | - | `data: {lines: [3, 7, 8]}` |
| HTML 부분 교체 | - | `/__content?file=<abs>` fetch → `#md-content.innerHTML` 교체 |
| Mermaid 재실행 | - | `mermaid.run()` |
| 부가 렌더 재적용 | - | highlight.js·KaTeX·ECharts·TOC 재실행 (innerHTML 교체로 초기화되므로) |
| 변경 줄 하이라이트 | 3 s | 노란 배경 + 좌측 박스 (`.changed`) |
| Fade out | 1.5 s | `.fade-out` 클래스 추가 |
| 영구 마커 전환 | - | `.marked`로 교체, 라인 번호만 강조 (`localStorage` 저장) |

## 테마

| 기능 | 동작 |
|------|------|
| 초기 테마 | macOS `defaults read -g AppleInterfaceStyle` 자동 감지 |
| 토글 버튼 | 우상단 (☀ 라이트 / 🌙 다크) |
| 저장 | `localStorage.mdwatch-theme` |
| Mermaid 테마 동기화 | `mermaid.initialize({theme: ...})` |
| highlight.js 테마 동기화 | github.min.css ↔ github-dark.min.css 스타일시트 스왑 |
| ECharts 테마 동기화 | 토글 시 dispose 후 dark/light 테마로 재초기화 |

## URL 구조 & 즐겨찾기

| 시나리오 | URL |
|---------|------|
| `~/argo/automation/foo.md` | `http://localhost:7474/automation/foo.md` |
| `~/argo/한글경로.md` | `http://localhost:7474/%ED%95%9C%EA%B8%80%EA%B2%BD%EB%A1%9C.md` |
| `~/Downloads/foo.md` (루트 밖) | `http://localhost:7474/?abs=%2FUsers%2Falvin%2FDownloads%2Ffoo.md` |
| 경로 traversal | HTTP 403 (`..` 정규화 후 ROOT 검증) |

브라우저에서 즐겨찾기/북마크/히스토리 모두 정상 동작합니다.

## 탭 관리

`mdwatch <file>` 또는 Finder 더블클릭 호출 시:

| 상태 | 결과 |
|------|------|
| 동일 URL 탭 이미 있음 | 그 탭을 active로 전환 + 윈도우 최상단 |
| 동일 URL 탭 없음 | 새 탭으로 열기 |

지원 브라우저 (기본 브라우저 자동 감지):
- Chromium 계열: Vivaldi, Chrome, Brave, Edge
- Safari
- 그 외 (Firefox, Arc): focus 미지원 → `open`으로 새 탭

## 다중 파일 동시 관리

- daemon 1개가 모든 파일을 관리합니다.
- 파일당 1개의 `fs.watch` 등록 (refcount 기반: 같은 파일 다중 탭은 watcher 공유).
- 탭 닫으면 SSE disconnect → refcount 0 되면 watcher 해제.

## 진입점

| 진입점 | 방법 | 동작 |
|--------|------|------|
| 터미널 | `mdwatch <file.md>` | daemon 보장 → node가 osascript로 focus/open |
| Finder | `.md` 더블클릭 | mdwatch.app → main.scpt → node `__resolve` → AppleScript로 focus/open |
| 직접 URL | 브라우저에서 `http://localhost:7474/...` | daemon이 떠있어야 응답 (없으면 한 번 mdwatch 실행으로 띄움) |

## 서버 관리

| 작업 | 명령 |
|------|------|
| 상태 확인 | `curl -s http://localhost:7474/__ping` (응답 `ok`) |
| 강제 종료 | `lsof -ti:7474 | xargs kill` |
| 로그 확인 | `tail -f /tmp/mdwatch.log` (Finder 경유) / `~/.mdwatch.log` (CLI 경유 daemon spawn) |
| 재시작 | 종료 후 `mdwatch <file>` 또는 `node ~/mdwatch/mdwatch.js __daemon__ &` |

## 인라인 블록 편집

| 기능 | 동작 |
|------|------|
| 편집 진입 | 렌더된 블록 **더블클릭** → 그 블록의 소스가 textarea로 펼쳐짐 |
| 저장 | `저장` 버튼 또는 **⌘↵**. 블록만 국소 치환(전체 재직렬화 없음) → git diff 최소 |
| 취소 | `취소` 또는 **Esc** |
| 충돌 처리 | 저장 직전 파일에서 원본 블록을 재탐색. 그새 그 블록이 바뀌었으면 **현재 내용을 나란히 보여주고** [덮어쓰기] 선택. 내 편집은 절대 소실되지 않음 |
| 줄 밀림 흡수 | AI가 다른 곳을 고쳐 블록이 밀려도 내용 기반 재탐색으로 자동 적용 |
| 초안 보존 | 편집 시작 시점부터 `localStorage`에 초안 저장 → SSE 갱신·브라우저 크래시에도 복원 |
| 비활성 대상 | embed(`{{$…}}`) 사용 파일, 비마크다운 파일 |
| 엔드포인트 | `GET /__source?file=&start=&end=`, `POST /__edit` (127.0.0.1 로컬 전용) |

## 테스트

| 항목 | 값 |
|------|------|
| 실행 | `npm test` (= `node --test test/`) |
| 프레임워크 | Node 내장 `node:test` (외부 의존성 없음) |
| 범위 | 순수 로직(diffLines·URL 매핑·traversal 방어·sliceLines·relocateAndReplace·renderContent) + HTTP 통합(`/__ping`·`/__source`·`/__edit` happy/conflict/embed/403) |

## 알려진 제약

- macOS 전용 (`defaults`, `osascript`, `open` 의존)
- 단일 사용자 (포트는 `MDWATCH_PORT` 환경변수로 변경 가능하나 daemon당 1개)
- 수식은 블록 수식만 지원 (인라인 `$...$` 미지원 — 금액 표기 오탐 방지 의도)
- 검색 기능 없음
- 파일 트리 탐색 없음
- HTML sanitization 없음 (의도된 trade-off: 인라인 style 지원)
- Firefox는 탭 focus 불가 (AppleScript dictionary 제한)
