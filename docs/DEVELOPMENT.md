# 개발 가이드

향후 기능 추가/수정 시 어디를 손대야 하는지 정리합니다.

## 코드 위치

| 파일 | 역할 |
|------|------|
| `src/mdwatch.js` | 단일 파일 — marked 인라인 번들 + HTTP 서버 + CLI |
| `src/main.applescript` | mdwatch.app AppleScript (Finder 핸들러) |
| `src/install-mdwatch.command` | 인스톨러 (Bash) |

설치된 실제 위치:
- `~/mdwatch/mdwatch.js` — Node 본체
- `/Applications/mdwatch.app/Contents/Resources/Scripts/main.scpt` — 컴파일된 AppleScript
- `/Applications/mdwatch.app/Contents/Info.plist` — 번들 메타데이터

## mdwatch.js 구조

```
1-87       marked v15 inline bundle (수정 불가, 외부 라이브러리)
88-100     상수 (PORT, ROOT, LOG_FILE)
101-130    엔트리 모드 판별 (DAEMON_MODE / RESOLVE_MODE / CLI)
131-180    URL ↔ 파일 매핑 (fileToUrl, urlToFile)
181-220    diffLines (변경 줄 계산)
221-300    marked renderer 확장 (data-line 주입, mermaid 변환)
301-540    buildHTML (전체 HTML 문서 생성 — CSS + 클라이언트 JS 포함)
541-620    HTTP 서버 (server.createServer, attachClient, detachClient, watchers)
621-720    브라우저 자동화 (BROWSER_MAP, detectDefaultBrowser, buildFocusScript, focusOrOpenTab)
721-끝     실행 분기 (if DAEMON_MODE / else if RESOLVE_MODE / else CLI)
```

## 일반적인 변경 시나리오

### 1. 새 브라우저 지원 추가

`BROWSER_MAP`과 `buildFocusScript`를 수정합니다.

```js
const BROWSER_MAP = {
  'com.vivaldi.vivaldi':    { name: 'Vivaldi',         kind: 'chromium' },
  // ... 새 브라우저:
  'org.mozilla.firefox':    { name: 'Firefox',         kind: 'firefox'  },
};

function buildFocusScript(browser) {
  if (browser.kind === 'firefox') {
    // Firefox는 AppleScript dictionary가 제한적이라 URL 비교 불가
    // → null 반환하여 fallback `open`으로 처리
    return null;
  }
  // ...
}
```

또한 `main.applescript`의 `focusOrOpenTab` 핸들러는 현재 Vivaldi 하드코딩입니다. 다른 브라우저 지원이 필요하면:

```applescript
on focusOrOpenTab(targetURL, browserName)
  -- browserName을 동적으로 받아 tell application "..." 호출
end focusOrOpenTab
```

`main.applescript` 변경 후 재컴파일 + 재서명:
```bash
osacompile -o /Applications/mdwatch.app/Contents/Resources/Scripts/main.scpt src/main.applescript
codesign --force --sign - /Applications/mdwatch.app
```

### 2. 코드 syntax highlighting — 구현됨 (2026-07-16)

- `code` renderer가 언어 명시 펜스에만 `language-*` 클래스 부여 (언어 없는 블록은 auto-detect 하지 않음 — ASCII 다이어그램 오염 방지)
- highlight.js@11 CDN + `github.min.css`/`github-dark.min.css` 두 스타일시트를 `disabled` 토글로 스왑 (`applyTheme`)
- SSE 갱신 후 `highlightCode()` 재실행

### 3. KaTeX 수식 지원 — 구현됨 (2026-07-16, 블록 수식만)

- 단독 줄 `$$...$$` 또는 ` ```math ` 펜스를 mermaid와 같은 마커 치환 방식으로 추출 → `.math-block[data-tex]` div → 클라이언트에서 `katex.render()`
- **인라인 `$...$`는 의도적으로 미지원**: "$12K 차지백" 같은 금액 표기가 수식으로 오탐되는 문제 + marked의 `_`/`*` 강조 변환과 충돌하기 때문. 마커 치환 방식이라 marked 간섭도 원천 차단됨
- KaTeX CDN은 문서에 수식이 있을 때만 로드 (`mathCount > 0`)

### 4. 목차(TOC) 자동 생성 — 구현됨 (2026-07-16)

- 클라이언트 측에서 `#md-content`의 h1-h4 수집 → 우상단 "☰ 목차" 접이식 패널 (서버 측 생성이 아니므로 `__content` 부분 갱신과 자연 호환)
- IntersectionObserver scroll-spy로 현재 섹션 강조, 표시 상태는 `localStorage.mdwatch-toc`
- 헤딩 2개 미만 문서는 버튼 자동 숨김. 1100px 미만 화면에서는 미표시

### 5. 포트 변경 — 환경변수 지원 (2026-07-16)

```bash
MDWATCH_PORT=8080 mdwatch file.md
```

기본 7474. 기존 브라우저 북마크가 깨지므로 신중하게.

### 6. ROOT 디렉토리 변경 — 환경변수 지원 (2026-07-16)

```bash
MDWATCH_ROOT=~/work mdwatch file.md
```

기본 `~/argo`. daemon이 이미 떠 있으면 재시작해야 반영됩니다 (`lsof -ti:7474 | xargs kill`).

### 7. 여러 루트 지원

URL 구조를 `/:root/path` 형태로 변경 필요. `urlToFile` / `fileToUrl` 양쪽 수정. 기존 북마크 호환성 검토 필요.

### 8. 부분 업데이트 최적화

현재 `__content` 엔드포인트는 **전체 HTML body**를 다시 보내고 클라이언트가 `innerHTML` 통째로 교체합니다. 큰 문서에서는 변경된 블록만 patch 하는 방식이 더 효율적입니다. 다만 mermaid 재실행 / 스타일 일관성 / DOM diff 등의 복잡성이 추가됩니다.

참고 (2026-07-16): innerHTML 교체 후 highlight.js·KaTeX·ECharts·TOC를 재적용하도록 수정됨. ECharts spec은 페이지 전역 변수가 아니라 각 div의 `data-spec` 속성에 내장되어, 부분 갱신 후에도 차트가 유지된다 (이전에는 SSE 갱신 시 차트가 사라지는 버그 있었음).

## 디버깅 팁

### daemon 로그 확인

```bash
# CLI 경유로 daemon 시작했을 때
tail -f ~/.mdwatch.log

# Finder 경유 (mdwatch.app)
tail -f /tmp/mdwatch.log
```

### TCC 권한 상태

```bash
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
  "SELECT service, client, indirect_object_identifier, auth_value FROM access \
   WHERE service='kTCCServiceAppleEvents';"
```

`auth_value`: 0=denied, 2=allowed.

### AppleScript 단독 테스트

```bash
osascript -e 'tell application "Vivaldi"
  return count of windows
end tell'
```

권한 문제면 `-1743` 에러.

### 서버 동작 확인

```bash
curl -s http://localhost:7474/__ping                    # → ok
curl -s -o /dev/null -w "%{http_code}\n" \
  "http://localhost:7474/some_file.md"                 # → 200/404/403
```

### 클라이언트 측 (브라우저)

DevTools → Network 탭에서:
- 초기 페이지 로드 (`GET /<path>`)
- SSE 연결 (`GET /__reload?file=...`, EventStream)
- 저장 시 부분 갱신 (`GET /__content?file=...`)

DevTools → Console에서 JavaScript 에러 확인. Mermaid 렌더링 실패 시 여기 출력.

## 코드 변경 후 적용

```bash
# 1. mdwatch.js 변경
cp mdwatch_source/src/mdwatch.js ~/mdwatch/mdwatch.js

# 2. daemon 재시작 필요
lsof -ti:7474 | xargs kill 2>/dev/null

# 3. main.applescript 변경 시
osacompile -o /Applications/mdwatch.app/Contents/Resources/Scripts/main.scpt \
  mdwatch_source/src/main.applescript
codesign --force --sign - /Applications/mdwatch.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f /Applications/mdwatch.app
```

## 테스트

### 자동화 테스트 (`npm test`)

`node:test`(무의존성) 기반. `test/mdwatch.test.js`:
- 순수 로직: `diffLines`, `fileToUrl`/`urlToFile`(traversal 클램프), `hasEmbeds`, `sliceLines`, `relocateAndReplace`, `renderContent`(data-line 계약)
- HTTP 통합: `server.listen(0)`으로 in-process 기동 → `/__ping`·`/__source`·`/__edit`(정상/충돌/embed거부/403)

```bash
npm test          # 또는 node --test test/
```

> 테스트가 함수를 `require` 할 수 있도록 `mdwatch.js`의 실행 분기는 `if (require.main === module)`로 감싸고 파일 끝에서 `module.exports` 한다. 새 순수 함수를 추가하면 export에 등록하고 케이스를 붙일 것.

### 수동 검증 체크리스트 (브라우저 UI — 자동화 대상 밖)

- [ ] `mdwatch ~/argo/README.md` → 새 탭 열림
- [ ] 같은 명령 재실행 → 새 탭 안 열림 (focus)
- [ ] Finder에서 `.md` 더블클릭 → 동일 동작
- [ ] 파일 편집 + 저장 → 변경 줄에 노란 박스, 3초 후 fade, 영구 마커 유지
- [ ] Mermaid 코드블록 → 다이어그램 렌더링
- [ ] 다크/라이트 토글 → mermaid도 테마 동기화
- [ ] 한글 파일명 → 정상 표시
- [ ] `~/Downloads/foo.md` (루트 밖) → `?abs=` URL로 동작
- [ ] daemon 종료 후 `mdwatch <file>` → daemon 자동 재기동
- [ ] 동시 5개 파일 열기 → 각각 독립적으로 watch + 변경 감지
- [ ] 탭 닫기 → 해당 파일 watcher 해제 (로그 확인 가능)
- [ ] **블록 더블클릭 → 편집기 열림, ⌘↵ 저장 → 파일 반영 + 변경 하이라이트**
- [ ] **편집 중 다른 세션/AI가 파일 수정 → 편집기 유지(리로드 큐잉), 닫으면 반영**
- [ ] **편집 중인 그 블록을 외부에서 바꾼 뒤 저장 → 충돌 UI + [덮어쓰기] 동작, 편집 내용 보존**
- [ ] **표/코드펜스 블록 편집 → 범위가 블록 전체를 정확히 덮는지**
- [ ] **embed(`{{$…}}`) 파일 → 편집 비활성(토스트)**
