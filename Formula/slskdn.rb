class Slskdn < Formula
  desc "Unofficial slskd fork with batteries-included Soulseek features"
  homepage "https://github.com/snapetech/slskdn"
  license "AGPL-3.0-or-later"
  version "2026101120-slskdn.349"
  on_macos do
    on_arm do
      url "https://github.com/snapetech/slskdn/releases/download/2026101120-slskdn.349/slskdn-main-osx-arm64.zip"
      sha256 "050b185ccfcf7aba5d7182c23f45b221e579606b8629f27ddb2521111ea39b34"
    end
    on_intel do
      url "https://github.com/snapetech/slskdn/releases/download/2026101120-slskdn.349/slskdn-main-osx-x64.zip"
      sha256 "ca6a25e00fb8ae4e42c1087746f0f370e37e3a922e7923cc957e66165b0d5cf3"
    end
  end
  on_linux do
    url "https://github.com/snapetech/slskdn/releases/download/2026101120-slskdn.349/slskdn-main-linux-glibc-x64.zip"
    sha256 "df949fb2c987eb0a29cdcf80993a18c9a24e67eec20c335b3fa15ca194cfbccb"
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
