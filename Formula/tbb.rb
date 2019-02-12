class Tbb < Formula
  desc "Rich and complete approach to parallelism in C++"
  homepage "https://www.threadingbuildingblocks.org/"
  url "https://github.com/01org/tbb/archive/2018_U3.tar.gz"
  version "2018_U3"
  sha256 "23793c8645480148e9559df96b386b780f92194c80120acce79fcdaae0d81f45"
  revision 9001

  bottle do
    cellar :any
    root_url "https://jeroen.github.io/bottles"
    sha256 "243d6b65ada32ecb64a888a818881d859c467efb2c3d2d381ad5b231164c61fb" => :el_capitan
  end

  # requires malloc features first introduced in Lion
  # https://github.com/Homebrew/homebrew/issues/32274
  depends_on "python@2" => :build
  depends_on "swig" => :build
  depends_on "cmake" => :build

  def install
    compiler = (ENV.compiler == :clang) ? "clang" : "gcc"
    args = %W[tbb_build_prefix=BUILDPREFIX compiler=#{compiler}]
    system "make", *args
    lib.install Dir["build/BUILDPREFIX_release/*.dylib"]

    args = %W[tbb_build_prefix=BUILDPREFIX compiler=#{compiler} extra_inc=big_iron.inc]
    system "make", *args
    lib.install Dir["build/BUILDPREFIX_release/*.a"]

    include.install "include/tbb"

    cd "python" do
      ENV["TBBROOT"] = prefix
      system "python", *Language::Python.setup_install_args(prefix)
    end

    system "cmake", "-DTBB_ROOT=#{prefix}",
                    "-DTBB_OS=Darwin",
                    "-DSAVE_TO=lib/cmake/TBB",
                    "-P", "cmake/tbb_config_generator.cmake"

    (lib/"cmake"/"TBB").install Dir["lib/cmake/TBB/*.cmake"]
  end

  test do
    (testpath/"test.cpp").write <<~EOS
      #include <tbb/task_scheduler_init.h>
      #include <iostream>

      int main()
      {
        std::cout << tbb::task_scheduler_init::default_num_threads();
        return 0;
      }
    EOS
    system ENV.cxx, "test.cpp", "-L#{lib}", "-ltbb", "-o", "test"
    system "./test"
  end
end
