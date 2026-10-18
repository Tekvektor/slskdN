class Slskdn < Formula
  desc "Unofficial slskd fork with batteries-included Soulseek features"
  homepage "https://github.com/snapetech/slskdn"
  license "AGPL-3.0-or-later"
  version "2026101723-slskdn.351"
  on_macos do
    on_arm do
      url "https://github.com/snapetech/slskdn/releases/download/2026101723-slskdn.351/slskdn-main-osx-arm64.zip"
      sha256 "760f37cffa4f47c2ba12a5e3447c44d4a31375dc6ff019bdd647cae9ca009a67"
    end
    on_intel do
      url "https://github.com/snapetech/slskdn/releases/download/2026101723-slskdn.351/slskdn-main-osx-x64.zip"
      sha256 "7746ec197e771a7936385207127cc8c2a0df3b647ae234cd8414e3ec34fffdcd"
    end
  end
  on_linux do
    url "https://github.com/snapetech/slskdn/releases/download/2026101723-slskdn.351/slskdn-main-linux-glibc-x64.zip"
    sha256 "d8a2c3b6d747208711d860a0856f054751f93942858e7c00d2a65e15ce3b7b11"
  end
  def install
    libexec.install Dir["*"]
    (bin/"slskd").write_exec_script libexec/"slskd"
    (bin/"slskdn").write_exec_script libexec/"slskd"
    if (libexec/"vpn-agent/slskdN-vpn-agent").exist?
      (bin/"slskdN-vpn-agent").write_exec_script libexec/"vpn-agent/slskdN-vpn-agent"
    end
  end
end
