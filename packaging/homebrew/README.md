# 배포 가이드 (npx · Homebrew)

mdwatch를 남들이 쉽게 설치하도록 하는 두 경로입니다. 화려한 배포 없이 "찾은 사람이 한 줄로 설치"가 목표.

## 1. npx — 지금 바로 동작 (별도 배포 불필요)

`package.json`의 `bin`(`mdwatch → src/mdwatch.js`)과 shebang 덕분에 npm 퍼블리시 없이 GitHub에서 직접 실행됩니다.

```bash
MDWATCH_ROOT="$PWD" npx github:alvin-pm/mdwatch some_file.md
```

- 의존성 0(marked 인라인 번들)이라 설치가 빠릅니다.
- CLI 전용 — Finder 더블클릭·탭 focus 같은 macOS 앱 통합은 소스 설치(`install-mdwatch.command`)로만.
- (선택) npm 퍼블리시 시 `npx mdwatch`로 짧아짐. 단 npm의 `mdwatch` 이름 가용 여부 확인 필요.

## 2. Homebrew tap — 한 줄 설치

포뮬러(`mdwatch.rb`)는 준비돼 있고, **릴리스 태그 + sha256**만 채우면 됩니다.

### 2-1. 릴리스 태그

```bash
git tag v1.0.0 && git push origin v1.0.0
# GitHub가 소스 tarball을 자동 생성:
#   https://github.com/alvin-pm/mdwatch/archive/refs/tags/v1.0.0.tar.gz
```

### 2-2. sha256 계산

```bash
curl -sL https://github.com/alvin-pm/mdwatch/archive/refs/tags/v1.0.0.tar.gz | shasum -a 256
```

### 2-3. tap 저장소 생성

Homebrew는 `homebrew-<name>` 규칙의 저장소를 tap으로 인식합니다.

```bash
# 새 저장소: alvin-pm/homebrew-mdwatch
#   Formula/mdwatch.rb  ← 이 폴더의 mdwatch.rb를 복사하고 sha256 채움
```

### 2-4. 사용자 설치

```bash
brew install alvin-pm/mdwatch/mdwatch   # = brew tap alvin-pm/mdwatch && brew install mdwatch
mdwatch some_file.md
```

> 포뮬러는 **CLI만** 설치합니다(node 래퍼 + `mdwatch` 명령). Finder 통합·탭 focus는 macOS 소스 설치 전용.
> 버전 올릴 때: `src/mdwatch.js`의 `VERSION` 상수와 포뮬러의 `url` 태그를 함께 갱신.

## 체크 (배포 전)

- [ ] `node --test` 통과 (CI 초록)
- [ ] `MDWATCH_ROOT=. node src/mdwatch.js --version` → `mdwatch 1.0.0`
- [ ] README 설치 섹션의 플랫폼·루트·보안 문구 확인
- [ ] 릴리스 노트 = CHANGELOG 요약
