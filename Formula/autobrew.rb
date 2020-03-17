class Autobrew < Formula
  desc "Build static R packages"
  homepage "https://github.com/r-hub/homebrew-cran"
  url "https://github.com/r-hub/homebrew-cran.git"
  bottle :unneeded
  version '0.1'

  conflicts_with "r", :because => "Only the official R for OSX supports binary packages. Don't use R from Homebrew."
  depends_on "rename"
  depends_on "pkg-config"
  depends_on "coreutils"

  def install
    libexec.install Dir["autobrew/*"]
    bin.install_symlink libexec/"autobrew.sh" => "autobrew"

    unless MacOS::CLT.installed?
      system "xcode-select", "--install"
    end
  end
end
