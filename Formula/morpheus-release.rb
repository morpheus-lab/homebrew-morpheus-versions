class MorpheusRelease < Formula
  desc "Modelling environment for multi-cellular systems biology"
  homepage "https://morpheus.gitlab.io/"
  license "BSD-3-Clause"
  head "https://gitlab.com/morpheus.lab/morpheus.git", branch: "release_2.3"

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

      # SBML import currently disabled by default due to libSBML build errors with some macOS SDKs
      args << "-DMORPHEUS_SBML=OFF" if build.without? "sbml"
    end

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    if OS.mac?
      bin.write_exec_script "#{prefix}/Morpheus.app/Contents/MacOS/morpheus"
      bin.write_exec_script "#{prefix}/Morpheus.app/Contents/MacOS/morpheus-gui"
    end
  end

  def post_install
    if OS.mac? && File.read("#{prefix}/Morpheus.app/Contents/Info.plist").include?("HOMEBREW_BIN_PATH")
      # Set PATH environment variable including Homebrew prefix in macOS app bundle
      inreplace "#{prefix}/Morpheus.app/Contents/Info.plist", "HOMEBREW_BIN_PATH", ENV["PATH"]
    end
  end

  def caveats
    if OS.mac?
      <<~EOS
        To start the Morpheus GUI, type the following command:

          morpheus-gui

        Or add Morpheus to your Applications folder with:

          ln -sf #{opt_prefix}/Morpheus.app /Applications

        For more information about this branch, visit: https://gitlab.com/morpheus.lab/morpheus/-/tree/release_2.3
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
