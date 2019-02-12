# Track Chrome stable, see https://omahaproxy.appspot.com/
class V8 < Formula
  desc "Google's JavaScript engine"
  homepage "https://github.com/v8/v8/wiki"
  url "https://chromium.googlesource.com/chromium/tools/depot_tools.git",
      :revision => "b69515579db8fb53d13c0d7acf4b5fc6ac4e2b5e"
  version "7.2.502.24" # the version of the v8 checkout, not a depot_tools version

  bottle do
    cellar :any_skip_relocation
    root_url "https://jeroen.github.io/bottles"
    sha256 "5383898b7795fbc6c5e84a24b2c5c4fa78fc52cb0b9f6ed3deda8956f847b891" => :el_capitan
  end

  # depot_tools/GN require Python 2.7+
  depends_on "python@2" => :build

  # https://bugs.chromium.org/p/chromium/issues/detail?id=620127
  depends_on :macos => :el_capitan

  def install
    # Add depot_tools in PATH
    ENV.prepend_path "PATH", buildpath
    # Prevent from updating depot_tools on every call
    # see https://www.chromium.org/developers/how-tos/depottools#TOC-Disabling-auto-update
    ENV["DEPOT_TOOLS_UPDATE"] = "0"

    # Initialize and sync gclient
    system "gclient", "root"
    system "gclient", "config", "--spec", <<~EOS
      solutions = [
        {
          "url": "https://github.com/v8/v8.git",
          "managed": False,
          "name": "v8",
          "deps_file": "DEPS",
          "custom_deps": {},
        },
      ]
      target_os = [ "mac" ]
      target_os_only = True
      cache_dir = "#{HOMEBREW_CACHE}/gclient_cache"
    EOS

    system "gclient", "sync",
      "-j", ENV.make_jobs,
      "-r", version,
      "--no-history",
      "-vvv"

    # Enter the v8 checkout
    cd "v8" do
      output_path = "out.gn/x64.release"

      gn_args = {
        :is_debug                     => false,
        :is_component_build           => false,
        :v8_static_library            => true,
        :symbol_level                 => 0,
        :enable_nacl                  => false,
        :v8_use_external_startup_data => false,
        :v8_enable_i18n_support       => false,
      }

      # Transform to args string
      gn_args_string = gn_args.map { |k, v| "#{k}=#{v}" }.join(" ")

      # Build with gn + ninja
      system "gn", "gen", "--args=#{gn_args_string}", output_path

      system "ninja", "-j", ENV.make_jobs, "-C", output_path,
             "-v", "d8"

      # Install all the things
      include.install Dir["include/*"]

      cd output_path do
        lib.install Dir["obj/lib*.a"]

        # Install d8 and icudtl.dat in libexec and symlink
        # because they need to be in the same directory.
        libexec.install Dir["d8", "icudt*.dat"]
        (bin/"d8").write <<~EOS
          #!/bin/bash
          exec "#{libexec}/d8" --icu-data-file="#{libexec}/icudtl.dat" "$@"
        EOS
      end
    end
  end

  test do
    assert_equal "Hello World!", shell_output("#{bin}/d8 -e 'print(\"Hello World!\");'").chomp
    t = "#{bin}/d8 -e 'print(new Intl.DateTimeFormat(\"en-US\").format(new Date(\"2012-12-20T03:00:00\")));'"
    assert_match %r{12/\d{2}/2012}, shell_output(t).chomp
  end
end
