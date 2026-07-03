# Homebrew formula for kubectl-sentinel.
#
# This belongs in a tap repo (github.com/GreenerPlatform/homebrew-tap) so users run:
#   brew tap greenerplatform/tap
#   brew install kubectl-sentinel
#
# The `url` and `sha256` are filled in when a release tag is cut (see
# .github/workflows/release.yml, which produces kubectl-sentinel-<tag>.tar.gz).
class KubectlSentinel < Formula
  desc "Deterministic Kubernetes cluster health snapshot for triage"
  homepage "https://github.com/GreenerPlatform/kubectl-sentinel"
  url "https://github.com/GreenerPlatform/kubectl-sentinel/releases/download/v1.2.0/kubectl-sentinel-v1.2.0.tar.gz"
  sha256 "REPLACE_WITH_RELEASE_ARCHIVE_SHA256"
  license "Apache-2.0"

  depends_on "jq"
  depends_on "kubernetes-cli"

  def install
    bin.install "kubectl-sentinel"
  end

  test do
    assert_match "kubectl-sentinel", shell_output("#{bin}/kubectl-sentinel --version")
  end
end
