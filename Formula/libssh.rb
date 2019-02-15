class Libssh < Formula
  desc "C library SSHv1/SSHv2 client and server protocols"
  homepage "https://www.libssh.org/"
  url "https://www.libssh.org/files/0.8/libssh-0.8.6.tar.xz"
  sha256 "1046b95632a07fc00b1ea70ee683072d0c8a23f544f4535440b727812002fd01"
  head "https://git.libssh.org/projects/libssh.git"

  bottle do
    cellar :any
    root_url "https://jeroen.github.io/bottles"
    sha256 "c9429b81061da732ba093ee64ad7ff8d98f3b49bb6cc14a26b654970a0391d36" => :el_capitan
  end

  depends_on "cmake" => :build
  depends_on "openssl"

  def install
    mkdir "build" do
      system "cmake", "..", "-DWITH_STATIC_LIB=ON",
                            "-DWITH_SYMBOL_VERSIONING=OFF",
                            *std_cmake_args
      system "make", "install"
    end
  end

  test do
    (testpath/"test.c").write <<~EOS
      #include <libssh/libssh.h>
      #include <stdlib.h>
      int main()
      {
        ssh_session my_ssh_session = ssh_new();
        if (my_ssh_session == NULL)
          exit(-1);
        ssh_free(my_ssh_session);
        return 0;
      }
    EOS
    system ENV.cc, "-I#{include}", "-L#{lib}", "-lssh",
           testpath/"test.c", "-o", testpath/"test"
    system "./test"
  end
end
