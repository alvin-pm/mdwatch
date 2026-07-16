# 변경 이력

날짜는 작업 완료 시점 기준입니다.

## 2026-07-16 — syntax highlighting + KaTeX + TOC + 환경변수 설정

DEVELOPMENT.md의 "일반적인 변경 시나리오" 중 2·3·4·5·6번 구현.

1. **코드 syntax highlighting** — highlight.js@11 CDN. 언어 명시 펜스만 대상 (언어 없는 블록은 평문 유지 — ASCII 다이어그램 보호). 다크/라이트 스타일시트 스왑.
2. **KaTeX 블록 수식** — 단독 줄 `$$...$$` / ` ```math ` 펜스. 마커 치환 방식이라 marked 간섭 없음. 인라인 `$...$`는 금액 표기 오탐 방지를 위해 의도적 미지원. 수식 있는 문서만 CDN 로드.
3. **목차(TOC) 패널** — 우상단 "☰ 목차" 접이식 패널, h1-h4 계층, 클릭 스크롤 + scroll-spy, 상태 localStorage 저장. 헤딩 2개 미만이면 자동 숨김.
4. **`MDWATCH_PORT` / `MDWATCH_ROOT` 환경변수** — 포트·루트 디렉토리 하드코딩 값 오버라이드.
5. **버그 수정: SSE 갱신 후 ECharts 차트 소실** — spec을 전역 변수 대신 각 div `data-spec` 속성에 내장하고, 부분 갱신 후 highlight/KaTeX/ECharts/TOC를 재적용.
6. **테마 토글 시 ECharts 재초기화** — 차트도 다크/라이트 동기화.
7. **BROWSER_MAP 확장** — Arc·Whale·Chromium·Opera 추가 (크로미움계, 실패 시 기존 `open` 폴백).

## 2026-07-16 — 코드블록 한글 고정폭 폰트 적용

배경: 코드블록 안 ASCII 다이어그램(박스 드로잉)이 한글 혼용 시 일그러져 보임. 기존 폰트 스택(`SF Mono` 우선)에 한글 글리프가 없어 한글만 비례폭 폰트(Apple SD Gothic Neo)로 폴백되고, 그 폭이 영문의 정확히 2배가 아니어서 정렬이 어긋나던 문제.

주요 변경:

1. **`code` 폰트 스택 변경**: `'D2Coding','Nanum Gothic Coding','SF Mono','Fira Code',monospace`
   - D2Coding·Nanum Gothic Coding은 한글 폭 = 영문 폭 × 2가 보장되는 한글 코딩 폰트.
2. **웹폰트 폴백 추가**: D2Coding 미설치 환경 대비 Google Fonts `Nanum Gothic Coding` `<link>` 추가 (팀 배포 대비).
3. **`pre` line-height 1.25 고정**: 박스 세로선 간 시각적 간격 완화 (본문 1.7 상속 대신, 1.5로 넣었다가 1.25로 추가 축소).

## 2026-06-05 — daemon화 + URL 단위 즐겨찾기 + 탭 focus

배경: 같은 파일을 열어도 매번 새 탭으로 열리고, URL이 항상 동일해서 브라우저 즐겨찾기 사용이 어려웠음.

주요 변경:

1. **상시 daemon 구조로 전환**
   - `mdwatch <file>` 첫 호출 시 백그라운드 자식 프로세스로 fork + detach. 터미널 닫혀도 살아있음.
   - 재호출 시 기존 daemon 그대로 두고 브라우저만 open.
   - 기존: 매 호출마다 `lsof | kill` 후 재시작.

2. **URL 매핑 도입**
   - ROOT(`~/argo`) 내부: `http://localhost:7474/<argo-relative-path>`
   - 외부: `http://localhost:7474/?abs=<URL-encoded-path>`
   - Path traversal 차단 (`..` 정규화 + ROOT 검증).
   - 기존: 모든 파일이 `http://localhost:7474/`로 동일 → 즐겨찾기 불가.

3. **파일별 동적 watcher**
   - SSE 연결 시 해당 파일에 watcher 등록, disconnect 시 해제 (refcount 기반).
   - 같은 파일 다중 탭은 watcher 공유.
   - 기존: daemon 시작 시 단일 파일만 감시 가능.

4. **현재 파일 경로 표시 UI**
   - 좌상단에 현재 파일의 ROOT-relative 경로 표시, hover 시 풀패스 tooltip.

5. **동일 URL 탭 focus**
   - `mdwatch <file>` 또는 Finder 더블클릭 시 기존 탭이 있으면 그 탭으로 focus, 없으면 새 탭.
   - 기본 브라우저 자동 감지 (`defaults read com.apple.LaunchServices/...`).
   - 지원: Vivaldi / Chrome / Brave / Edge / Safari (AppleScript). Firefox / Arc는 fallback.

6. **`__resolve` 모드 추가**
   - mdwatch.app의 main.scpt가 호출. daemon 보장 + URL을 stdout으로 반환 후 즉시 종료.
   - main.scpt가 URL을 받아 AppleScript로 직접 Vivaldi 제어 → TCC 권한 chain이 mdwatch.app 단위로 단순화.

7. **버그 픽스**
   - `BROWSER_MAP`(`const`)이 함수 호출 시점보다 뒤에 정의되어 TDZ 에러 → silent catch가 null 반환 → focus가 안 되던 문제. 함수/상수 정의를 모두 호출부 위로 이동.

8. **main.applescript 신규 작성**
   - 기존: `do shell script "node mdwatch.js <file>"` 한 줄
   - 신규: `do shell script "node mdwatch.js __resolve <file>"`로 URL 획득 → AppleScript `tell application "Vivaldi"`로 focus or open.

설치 후 첫 사용 시 macOS가 "mdwatch가 Vivaldi 제어 권한을 요청합니다" 다이얼로그를 띄움. [허용] 클릭 1회로 영구 적용.

## 초기 버전 (2026-03~04)

- marked v15 인라인 번들 (npm install 불필요)
- HTTP 서버 (포트 7474) + fs.watch + SSE 부분 업데이트
- 줄 번호 gutter, 변경 줄 하이라이트, 영구 마커, 자동 스크롤
- Mermaid 다이어그램 지원 (CDN), 다크/라이트 테마, localStorage 저장
- mdwatch.app (osacompile) + Launch Services 등록
- 자동 인스톨러 (Node.js 자동 감지/설치)
- 단일 파일 감시 (한 번에 1개 파일만 가능)
- URL이 모두 동일 (`http://localhost:7474/`) → 즐겨찾기 불가
- 새 파일 열 때마다 기존 서버 kill 후 재시작
