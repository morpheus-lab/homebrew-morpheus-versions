class MorpheusAT231 < Formula
  desc "Modelling environment for multi-cellular systems biology"
  homepage "https://morpheus.gitlab.io/"
  url "https://gitlab.com/morpheus.lab/morpheus/-/archive/v2.3.1/morpheus-v2.3.1.tar.gz"
  sha256 "33c12825f0e0a9b52478713cd42936aaa3e92c50d21db50d6bc61099dd89c95f"
  license "BSD-3-Clause"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+(?:_?\d+)?)$/i)
  end

  depends_on "boost" => :build
  depends_on "cmake" => :build
  depends_on "doxygen" => :build
  depends_on "ffmpeg" # Runtime dependencies
  depends_on "gnuplot"
  depends_on "graphviz"
  depends_on "libomp"
  depends_on "libtiff"
  depends_on "qt@5"

  uses_from_macos "bzip2"
  uses_from_macos "libxml2"
  uses_from_macos "zlib"

  def install
    args = std_cmake_args
    args << "-DMORPHEUS_RELEASE_BUNDLE=ON" if OS.mac?

    system "cmake", ".", *args
    system "make", "install"

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
    if OS.mac?
      <<~EOS
        To start the Morpheus GUI, type the following command:

          morpheus-gui

        Or add Morpheus to your Applications folder with:

          ln -sf #{prefix}/Morpheus.app /Applications

        For more information about this release, visit: https://morpheus.gitlab.io/download/2.3.1/
      EOS
    end
  end

  test do
    (testpath/"test.xml").write <<~EOF
      <?xml version='1.0' encoding='UTF-8'?>
      <MorpheusModel version="4">
          <Description>
              <Details></Details>
              <Title></Title>
          </Description>
          <Space>
              <Lattice class="linear">
                  <Neighborhood>
                      <Order>1</Order>
                  </Neighborhood>
                  <Size value="100,  0.0,  0.0" symbol="size"/>
              </Lattice>
              <SpaceSymbol symbol="space"/>
          </Space>
          <Time>
              <StartTime value="0"/>
              <StopTime value="0"/>
              <TimeSymbol symbol="time"/>
          </Time>
          <Analysis>
              <ModelGraph include-tags="#untagged" format="dot" reduced="false"/>
          </Analysis>
      </MorpheusModel>
    EOF

    assert_match "Simulation finished", shell_output("#{bin}/morpheus --file test.xml")
  end
end
