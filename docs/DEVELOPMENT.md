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

### 2. 코드 syntax highlighting 추가

`buildHTML` 안의 `<script>` 영역에 highlight.js CDN 추가 + `code` renderer 수정:

```js
// marked.use({renderer: {code(token) {...}}}) 안
return `<pre data-line="${l}"><code class="language-${token.lang || 'plaintext'}">${escaped}</code></pre>\n`;

// buildHTML 안 <head>:
<script src="https://cdn.jsdelivr.net/npm/highlight.js@11/lib/core.min.js"></script>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/highlight.js@11/styles/github.min.css">
```

다크 테마 대응을 위해 `github.css` / `github-dark.css` 동적 swap이 필요합니다.

### 3. KaTeX 수식 지원

`marked.use({extensions: [...]})`로 `$...$`, `$$...$$` 토크나이저 추가. 또는 KaTeX 자동 렌더링 (`renderMathInElement`)을 SSE 갱신 후 호출.

### 4. 목차(TOC) 자동 생성

`heading` renderer에서 슬러그 + 레벨 수집 → buildHTML 시 좌측 사이드바 출력. CSS grid로 본문/TOC 2열 레이아웃.

### 5. 포트 변경

```js
const PORT = 7474;  // ← 여기
```

기존 브라우저 북마크가 깨지므로 신중하게.

### 6. ROOT 디렉토리 변경

```js
const ROOT = path.resolve(process.env.HOME, 'argo');  // ← 여기
```

또는 환경변수로 받기:
```js
const ROOT = process.env.MDWATCH_ROOT || path.resolve(process.env.HOME, 'argo');
```

### 7. 여러 루트 지원

URL 구조를 `/:root/path` 형태로 변경 필요. `urlToFile` / `fileToUrl` 양쪽 수정. 기존 북마크 호환성 검토 필요.

### 8. 부분 업데이트 최적화

현재 `__content` 엔드포인트는 **전체 HTML body**를 다시 보내고 클라이언트가 `innerHTML` 통째로 교체합니다. 큰 문서에서는 변경된 블록만 patch 하는 방식이 더 효율적입니다. 다만 mermaid 재실행 / 스타일 일관성 / DOM diff 등의 복잡성이 추가됩니다.

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

## 테스트 체크리스트

수동 검증 절차 (자동화 테스트 없음):

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
