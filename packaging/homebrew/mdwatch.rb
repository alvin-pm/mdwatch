# Homebrew formula (tap용). 릴리스 태그 후 sha256만 채우면 동작합니다.
# 배포 절차는 이 폴더의 README.md 참조.
class Mdwatch < Formula
  desc "Markdown viewer for the AI-authoring loop: watch external edits, edit inline"
  homepage "https://github.com/alvin-pm/mdwatch"
  url "https://github.com/alvin-pm/mdwatch/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "REPLACE_AFTER_TAGGING_RELEASE" # curl -sL <tarball> | shasum -a 256
  license "MIT"

  depends_on "node"

  def install
    libexec.install "src/mdwatch.js"
    (bin/"mdwatch").write <<~SH
      #!/bin/bash
      exec "#{Formula["node"].opt_bin}/node" "#{libexec}/mdwatch.js" "$@"
    SH
  end

  test do
    assert_match "mdwatch #{version}", shell_output("#{bin}/mdwatch --version")
  end
end
