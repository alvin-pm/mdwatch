# 설치 가이드

팀원에게 배포할 때 다음 절차를 안내합니다.

## 1. 사전 요구사항

- macOS 12 이상
- Node.js 16 이상 (없으면 인스톨 스크립트가 자동으로 Homebrew + Node 설치)

## 2. Node.js 설치 (Homebrew 없는 환경)

인스톨 스크립트가 Homebrew를 자동 설치할 수 있지만, 사내 정책 등으로 Homebrew를 쓸 수 없거나 별도로 Node.js를 관리하는 경우 아래 중 하나를 선택합니다.

### 옵션 A — 공식 인스톨러 (가장 간단)

1. [nodejs.org](https://nodejs.org/) 접속
2. **LTS 버전** 다운로드 (macOS Installer `.pkg`)
3. `.pkg` 더블클릭 → 안내대로 설치
4. 설치 확인:
   ```bash
   node -v          # v20.x.x 또는 v22.x.x 등 (16 이상이면 OK)
   which node       # /usr/local/bin/node (Intel) 또는 /opt/homebrew/bin/node (Apple Silicon)
   ```

### 옵션 B — nvm (버전 여러 개 관리)

```bash
# nvm 설치
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# 새 셸 열거나
source ~/.zshrc

# Node LTS 설치
nvm install --lts
nvm use --lts
```

### 옵션 C — Homebrew 신규 설치 (선호 시)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install node
```

Node.js가 16 이상 설치되어 있는 상태에서 다음 단계로 넘어갑니다. 인스톨 스크립트는 `command -v node`, 표준 경로(`/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`), nvm 디렉토리(`~/.nvm/versions/node/<latest>`) 순으로 자동 탐지합니다.

### 사내망 / 제한된 네트워크에서

위 방법 모두 인터넷 접속이 필요합니다. 오프라인이거나 외부 다운로드가 막혀 있다면 사내 미러나 사전 다운로드한 `.pkg` 파일을 USB 등으로 전달받아 설치합니다.

## 3. 자동 설치

```bash
# mdwatch_source/src/install-mdwatch.command 실행
cd /path/to/mdwatch_source/src
./install-mdwatch.command
```

자동으로 수행되는 작업:
1. Node.js 확인 — 이미 설치되어 있으면 그것을 사용. 없으면 Homebrew를 통해 자동 설치 시도 (Homebrew 없는 환경이면 위 **2. Node.js 설치** 절차로 먼저 설치 권장)
2. `~/mdwatch/mdwatch.js` 복사
3. `/Applications/mdwatch.app` 생성 (Info.plist 등록, Launch Services 갱신, 기본 브라우저 자동 감지 후 main.scpt 컴파일·재서명)
4. `~/.zshrc`에 `alias mdwatch='node ~/mdwatch/mdwatch.js'` 추가

## 4. 설치 후 수동 설정

### (1) ROOT 디렉토리 변경 (선택)

기본값은 `~/argo`입니다. 다른 경로를 쓰려면 `~/mdwatch/mdwatch.js` 상단 수정:

```js
const ROOT = path.resolve(process.env.HOME, 'your-root-here');
```

### (2) `.md` 파일 기본 앱 지정

Finder 더블클릭으로 열리게 하려면:

1. Finder에서 아무 `.md` 파일 선택
2. `Cmd + I` (정보 가져오기)
3. **Open with** → `mdwatch` 선택
4. **Change All...** 클릭

### (3) Warp 사용자

Warp 내장 MD 뷰어를 끄지 않으면 `.md` 클릭이 Warp에서 처리됩니다.

**Warp Settings → Features → "Open Markdown files in Warp's Markdown viewer" → OFF**

### (4) 브라우저 자동화 권한 (첫 사용 시)

처음 `.md` 파일을 더블클릭하면 macOS가 다음과 같은 다이얼로그를 띄웁니다:

> mdwatch가 Vivaldi를 제어하려고 합니다. ... [허용 / 거부]

**반드시 [허용] 클릭하세요.** 거부하면 같은 URL을 다시 열어도 focus되지 않고 매번 새 탭이 생성됩니다.

거부했을 때 복구 방법:
```bash
tccutil reset AppleEvents local.mdwatch
```
또는 `System Settings → Privacy & Security → Automation → mdwatch → [브라우저] 체크`

## 5. 사용 확인

```bash
# 터미널에서
mdwatch ~/argo/README.md       # 새 탭 1개 열림
mdwatch ~/argo/README.md       # 새 탭 안 열리고 기존 탭으로 focus

# Finder에서
.md 파일 더블클릭 → 같은 동작
```

서버 상태:
```bash
curl -s http://localhost:7474/__ping    # → ok
```

## 6. 제거

```bash
# daemon 종료
lsof -ti:7474 | xargs kill 2>/dev/null

# 파일 제거
rm -rf ~/mdwatch
rm -rf /Applications/mdwatch.app
rm /tmp/mdwatch.log ~/.mdwatch.log 2>/dev/null

# alias 제거 (~/.zshrc 에서 "mdwatch" 라인 삭제)
# .md 기본 앱 재설정 (Finder Cmd+I)

# TCC 권한 제거 (선택)
tccutil reset AppleEvents local.mdwatch
```

## 7. 트러블슈팅

| 증상 | 원인 / 해결 |
|------|-------------|
| `.md` 더블클릭이 다른 앱에서 열림 | Finder → Cmd+I → Open with → mdwatch → Change All |
| 매번 새 탭이 열림 (focus 안 됨) | TCC 권한 누락. `tccutil reset AppleEvents local.mdwatch` 후 다시 시도하고 다이얼로그 [허용] |
| `port 7474 already in use` | 다른 프로세스가 점유. `lsof -i:7474`로 확인, 필요 시 종료 |
| Mermaid가 빈 박스로 표시 | 네트워크에서 `mermaid@11` CDN 차단. 사내 프록시 환경에서 가능 |
| 한글 파일명에서 404 | URL 인코딩 문제. 디코딩 후 `fs.realpathSync` 실패 시 발생. `~/argo` 안의 정상 경로면 동작해야 함 |
| Finder 더블클릭 시 변경사항 미반영 | `/tmp/mdwatch.log` 확인 — node가 실행 자체에 실패하는 경우 NODE_BIN 경로 불일치 가능 (`main.applescript`의 `NODE_BIN` 수정) |

## 8. 환경별 NODE_BIN 경로

`src/main.applescript` 상단에 하드코딩된 NODE_BIN은 nvm v18.20.0 기준입니다. 다른 환경 (Homebrew Node, fnm 등)이면 설치 스크립트가 자동 검출하여 컴파일하지만, 수동 변경이 필요할 때:

```applescript
property NODE_BIN : "/opt/homebrew/bin/node"
```

변경 후 재컴파일:
```bash
osacompile -o /Applications/mdwatch.app/Contents/Resources/Scripts/main.scpt \
  /path/to/mdwatch_source/src/main.applescript
codesign --force --sign - /Applications/mdwatch.app
```
