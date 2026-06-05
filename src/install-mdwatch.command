#!/usr/bin/env bash
# ============================================================
# install-mdwatch.command
# Markdown + Mermaid live preview — daemon + URL focus 지원 버전
# macOS 전용 | Node.js 16+ 필요
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC}   $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERR]${NC}  $1"; exit 1; }

INSTALL_DIR="$HOME/mdwatch"
APP_PATH="/Applications/mdwatch.app"

echo ""
echo "  ┌─────────────────────────────────────────┐"
echo "  │   mdwatch 설치 스크립트                  │"
echo "  │   Markdown + Mermaid + daemon + focus    │"
echo "  └─────────────────────────────────────────┘"
echo ""

# ── 1. Node.js 확인 및 자동 설치 ────────────────────────────
info "Node.js 확인 중..."

for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  [ -x "$_brew" ] && eval "$("$_brew" shellenv)" && break
done

[ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh" 2>/dev/null || true

_find_node() {
  for _p in \
    "$(command -v node 2>/dev/null)" \
    /opt/homebrew/bin/node \
    /usr/local/bin/node \
    /usr/bin/node; do
    [ -x "$_p" ] && echo "$_p" && return 0
  done
  if [ -d "$HOME/.nvm/versions/node" ]; then
    local _latest
    _latest=$(ls "$HOME/.nvm/versions/node" 2>/dev/null | sort -V | tail -1)
    local _p="$HOME/.nvm/versions/node/$_latest/bin/node"
    [ -x "$_p" ] && echo "$_p" && return 0
  fi
  return 1
}

NODE_PATH=$(_find_node || true)

if [ -z "$NODE_PATH" ]; then
  warn "Node.js가 없습니다. 자동 설치를 시작합니다..."

  BREW_PATH=""
  for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$_brew" ] && BREW_PATH="$_brew" && break
  done

  if [ -z "$BREW_PATH" ]; then
    info "Homebrew 설치 중... (관리자 비밀번호가 필요할 수 있습니다)"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || \
      error "Homebrew 설치 실패. https://brew.sh 에서 수동 설치 후 다시 실행하세요."
    for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      [ -x "$_brew" ] && BREW_PATH="$_brew" && eval "$("$_brew" shellenv)" && break
    done
    success "Homebrew 설치 완료"
  fi

  info "Node.js 설치 중..."
  "$BREW_PATH" install node || error "Node.js 설치 실패. https://nodejs.org 에서 수동 설치 후 다시 실행하세요."
  NODE_PATH=$(_find_node || true)
  [ -z "$NODE_PATH" ] && error "Node.js 설치 후에도 경로를 찾을 수 없습니다."
  success "Node.js 설치 완료"
fi

NODE_VER=$("$NODE_PATH" -e "process.stdout.write(process.versions.node)")
NODE_MAJOR=${NODE_VER%%.*}
if [ "$NODE_MAJOR" -lt 16 ]; then
  warn "Node.js 버전이 낮습니다 (현재: v${NODE_VER}). 업그레이드 중..."
  brew upgrade node || error "Node.js 업그레이드 실패. 수동으로 Node.js 16 이상을 설치해주세요."
  NODE_PATH=$(_find_node || true)
  NODE_VER=$("$NODE_PATH" -e "process.stdout.write(process.versions.node)")
fi
success "Node.js v${NODE_VER} → $NODE_PATH"

# ── 2. mdwatch.js 복사 ────────────────────────────────────────
info "mdwatch.js 설치 중..."
mkdir -p "$INSTALL_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ ! -f "$SCRIPT_DIR/mdwatch.js" ]; then
  error "mdwatch.js를 찾을 수 없습니다. 이 스크립트와 같은 디렉토리에 mdwatch.js가 있어야 합니다."
fi

if [ "$(realpath "$SCRIPT_DIR/mdwatch.js")" != "$(realpath "$INSTALL_DIR/mdwatch.js" 2>/dev/null)" ]; then
  cp "$SCRIPT_DIR/mdwatch.js" "$INSTALL_DIR/mdwatch.js"
fi
chmod +x "$INSTALL_DIR/mdwatch.js"
success "mdwatch.js → $INSTALL_DIR/mdwatch.js"

# ── 3. 기본 브라우저 감지 (focus 대상 결정) ─────────────────
DEFAULT_BUNDLE=$(defaults read com.apple.LaunchServices/com.apple.launchservices.secure 2>/dev/null | \
  awk '/LSHandlerRoleAll/{role=$3} /LSHandlerURLScheme = http;/{print role; exit}' | tr -d '";,')

case "$DEFAULT_BUNDLE" in
  com.vivaldi.vivaldi)   BROWSER_APP="Vivaldi" ;;
  com.google.chrome)     BROWSER_APP="Google Chrome" ;;
  com.brave.browser)     BROWSER_APP="Brave Browser" ;;
  com.microsoft.edgemac) BROWSER_APP="Microsoft Edge" ;;
  com.apple.safari)      BROWSER_APP="Safari" ;;
  *)                     BROWSER_APP="Vivaldi"; warn "기본 브라우저 감지 실패 → Vivaldi로 가정 (main.applescript 수정으로 변경 가능)" ;;
esac
info "기본 브라우저: $BROWSER_APP"

# ── 4. mdwatch.app 생성 ───────────────────────────────────────
info "mdwatch.app 생성 중..."

cat > /tmp/mdwatch-applet.applescript << APPLESCRIPT
-- mdwatch.app — Finder에서 .md 파일을 열 때 호출됨.
-- node에서 URL을 받아 브라우저에서 동일 URL 탭이 있으면 focus, 없으면 새 탭.
-- AppleEvent는 이 스크립트(=mdwatch.app)가 직접 발송 → TCC 권한이 mdwatch.app 단위로 부여됨.

property NODE_BIN : "$NODE_PATH"
property MDWATCH_JS : "$INSTALL_DIR/mdwatch.js"

on run {input, parameters}
	if input is missing value then return
	if (count of input) is 0 then return
	repeat with aFile in input
		my handleFile(POSIX path of aFile)
	end repeat
end run

on open theFiles
	repeat with aFile in theFiles
		my handleFile(POSIX path of aFile)
	end repeat
end open

on handleFile(filePath)
	set targetURL to ""
	try
		set targetURL to do shell script (quoted form of NODE_BIN) & " " & (quoted form of MDWATCH_JS) & " __resolve " & quoted form of filePath
	on error errMsg number errNum
		display dialog "mdwatch resolve failed (" & errNum & "): " & errMsg buttons {"OK"} default button "OK"
		return
	end try
	if targetURL is "" then return
	my focusOrOpenTab(targetURL)
end handleFile

on focusOrOpenTab(targetURL)
	tell application "$BROWSER_APP"
		set found to false
		repeat with w in windows
			set tabList to tabs of w
			repeat with i from 1 to count of tabList
				if URL of (item i of tabList) is targetURL then
					set active tab index of w to i
					set index of w to 1
					activate
					set found to true
					exit repeat
				end if
			end repeat
			if found then exit repeat
		end repeat
		if not found then
			open location targetURL
			activate
		end if
	end tell
end focusOrOpenTab
APPLESCRIPT

osacompile -o "$APP_PATH" /tmp/mdwatch-applet.applescript

# Info.plist에 번들 ID와 문서 타입 등록
PLIST="$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string local.mdwatch"                        "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes array"                                    "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0 dict"                                   "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions array"           "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions:0 string md"     "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions:1 string markdown" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeName string Markdown"       "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Viewer"         "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSHandlerRank string Owner"             "$PLIST" 2>/dev/null || true

# 재서명 (adhoc) — main.scpt 수정 후 서명 무효화 방지
codesign --force --sign - "$APP_PATH" 2>&1 | grep -v "replacing existing signature" || true

# Launch Services 등록
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_PATH"

success "mdwatch.app → $APP_PATH (focus: $BROWSER_APP)"

# ── 5. shell alias 추가 ───────────────────────────────────────
info "shell alias 추가 중..."

SHELL_RC=""
if [ -f "$HOME/.zshrc" ]; then
  SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
  SHELL_RC="$HOME/.bashrc"
fi

ALIAS_LINE="alias mdwatch='$NODE_PATH $INSTALL_DIR/mdwatch.js'"

if [ -n "$SHELL_RC" ] && ! grep -q "mdwatch" "$SHELL_RC" 2>/dev/null; then
  echo "" >> "$SHELL_RC"
  echo "# Markdown live preview with Mermaid" >> "$SHELL_RC"
  echo "$ALIAS_LINE" >> "$SHELL_RC"
  success "alias 추가됨 → $SHELL_RC"
else
  warn "alias가 이미 있거나 shell RC를 찾을 수 없어 건너뜁니다."
  info "수동으로 추가: $ALIAS_LINE"
fi

# ── 6. 기본 앱 설정 안내 ──────────────────────────────────────
echo ""
echo "  ┌─────────────────────────────────────────────────────┐"
echo "  │   .md 파일 기본 앱 설정 (수동 필요)                  │"
echo "  ├─────────────────────────────────────────────────────┤"
echo "  │   1. Finder에서 아무 .md 파일 선택                   │"
echo "  │   2. Cmd+I (정보 가져오기)                           │"
echo "  │   3. 'Open with' → mdwatch 선택                      │"
echo "  │   4. 'Change All...' 클릭                            │"
echo "  └─────────────────────────────────────────────────────┘"
echo ""
echo "  ┌─────────────────────────────────────────────────────┐"
echo "  │   첫 사용 시 권한 다이얼로그                          │"
echo "  ├─────────────────────────────────────────────────────┤"
echo "  │   처음 .md 파일을 더블클릭하면 macOS가                │"
echo "  │   \"mdwatch가 $BROWSER_APP 를 제어하려고 합니다\"      │"
echo "  │   다이얼로그를 띄웁니다.                              │"
echo "  │                                                      │"
echo "  │   → [허용] 클릭 (한 번만, 영구 적용)                  │"
echo "  │                                                      │"
echo "  │   거부했을 경우 복구:                                 │"
echo "  │   tccutil reset AppleEvents local.mdwatch            │"
echo "  └─────────────────────────────────────────────────────┘"
echo ""

success "설치 완료!"
echo ""
echo "  사용법:"
echo "    터미널: mdwatch <파일.md>     # alias 적용 후"
echo "    클릭:   .md 파일 더블클릭     # 기본 앱 설정 후"
echo ""
echo "  적용:"
echo "    source $SHELL_RC"
echo ""
echo "  ┌─────────────────────────────────────────────────────┐"
echo "  │   Warp 사용자 추가 설정                              │"
echo "  ├─────────────────────────────────────────────────────┤"
echo "  │   Warp의 내장 MD 뷰어를 비활성화해야                 │"
echo "  │   .md 파일 클릭 시 mdwatch로 열립니다.               │"
echo "  │                                                      │"
echo "  │   Warp Settings → Features →                        │"
echo "  │   'Open Markdown files in Warp's Markdown viewer'   │"
echo "  │   → OFF                                             │"
echo "  └─────────────────────────────────────────────────────┘"
echo ""
