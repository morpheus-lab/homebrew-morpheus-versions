class MorpheusAT220b2 < Formula
  desc "Modeling environment for Multi-Cellular Systems Biology"
  homepage "https://morpheus.gitlab.io"
  url "https://gitlab.com/morpheus.lab/morpheus/-/archive/v2.2.0-beta2/morpheus-v2.2.0-beta2.tar.gz"
  version "2.2.0b2"
  sha256 "b99b8cba61d206c084882f066d04914cee03eab706e55f3c161445f8d929d981"
  license "BSD-3-Clause"

  option "with-sbml", "Enable SBML import via the internal libSBML build"

  depends_on "boost" => :build
  depends_on "cmake" => :build
  depends_on "doxygen" => :build
  depends_on "ninja" => :build
  depends_on "gnuplot"
  depends_on "graphviz"
  depends_on "libomp"
  depends_on "libtiff"
  depends_on "qt@5"
  depends_on "ffmpeg" => :recommended # Runtime dependencies

  uses_from_macos "bzip2"
  uses_from_macos "libxml2"
  uses_from_macos "zlib"

  def install
    args = []
    args << "-G Ninja"

    if OS.mac?
      args << "-DMORPHEUS_RELEASE_BUNDLE=ON"
      args << "-DMORPHEUS_BINARY_SUFFIX=#{version}" # Append version to binary name

      # SBML import currently disabled by default due to libSBML build errors with some macOS SDKs
      args << "-DMORPHEUS_SBML=OFF" if build.without? "sbml"
    end

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    if OS.mac?
      bin.write_exec_script "#{prefix}/Morpheus.app/Contents/MacOS/morpheus"

      (bin/"morpheus-gui").write <<~EOS
        #!/bin/bash
        open #{prefix}/Morpheus.app
      EOS
      (bin/"morpheus-gui").chmod 0555
    end
  end

  def post_install
    if OS.mac?
      # Set PATH environment variable including Homebrew prefix in macOS app bundle
      inreplace "#{prefix}/Morpheus.app/Contents/Info.plist", "<key>CFBundleExecutable</key>",
        <<~EOS.chomp
          <key>LSEnvironment</key>
          <dict>
              <key>PATH</key>
              <string>#{ENV["PATH"]}</string>
          </dict>
          <key>CFBundleExecutable</key>
        EOS
    end
  end

  def caveats
    <<~EOS
      To start the Morpheus GUI, type the following command:

        morpheus-gui

      Or add Morpheus to your Applications folder with:

        ln -sf #{opt_prefix}/Morpheus.app /Applications/Morpheus@#{version}.app

      For more information about this release, visit: https://morpheus.gitlab.io/download/2.2.0-b2/
    EOS
  end
end
