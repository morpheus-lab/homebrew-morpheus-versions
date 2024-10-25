class MorpheusQt6 < Formula
  desc "Modeling environment for multi-cellular systems biology"
  homepage "https://morpheus.gitlab.io/"
  license "BSD-3-Clause"
  head "https://gitlab.com/morpheus.lab/dev/morpheus.git", branch: "qt6-port"

  option "with-sbml", "Enable SBML import via the internal libSBML build"

  depends_on "boost" => :build
  depends_on "cmake" => :build
  depends_on "doxygen" => :build
  depends_on "ninja" => :build
  depends_on "gnuplot"
  depends_on "graphviz"
  depends_on "libomp"
  depends_on "libtiff"
  depends_on "qt@6"
  depends_on "ffmpeg" => :recommended # Runtime dependencies
  uses_from_macos "bzip2"
  uses_from_macos "libxml2"
  uses_from_macos "zlib"

  # conflicts_with "qt@5", because: "this formula is designed to work with qt@6 only"

  def install
    # has to build with Ninja until: https://gitlab.kitware.com/cmake/cmake/-/issues/25142
    args = ["-G Ninja"]

    if OS.mac?
      args << "-DMORPHEUS_RELEASE_BUNDLE=ON"
      args << "-DBREW_FORMULA_DEPLOYMENT=ON"

      # Append branch name and Git commit hash to binary suffix
      args << "-DMORPHEUS_BINARY_SUFFIX=#{self.class.head.specs[:branch]}-#{`git rev-parse HEAD`.strip[0, 7]}"

      # SBML import currently disabled by default due to libSBML build errors with some macOS SDKs
      args << "-DMORPHEUS_SBML=OFF" if build.without? "sbml"

      # Qt6 paths
      # args << "-DCMAKE_PREFIX_PATH=#{Formula["qt@6"].opt_prefix}"
      # args << "-DQt6_DIR=#{Formula["qt@6"].opt_lib}/cmake/Qt6"

      # Set the Qt WebEngine resources directory explicitly
      # qt_webengine_resources_dir = "#{Formula["qt@6"].opt_lib}/QtWebEngineCore.framework/Versions/A/Resources"
      # args << "-DQT_WEBENGINE_RESOURCES_DIR=#{qt_webengine_resources_dir}"
    end

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    return unless OS.mac?

    bin.write_exec_script "#{prefix}/Morpheus.app/Contents/MacOS/morpheus"
    bin.write_exec_script "#{prefix}/Morpheus.app/Contents/MacOS/morpheus-gui"

    # Set PATH environment variable including Homebrew prefix in macOS app bundle
    inreplace "#{prefix}/Morpheus.app/Contents/Info.plist", "HOMEBREW_BIN_PATH", "#{HOMEBREW_PREFIX}/bin"
  end

  def caveats
    on_macos do
      <<~EOS
        To start the Morpheus GUI, type the following command:

          morpheus-gui

        Or add Morpheus to your Applications folder with:

          ln -sf #{opt_prefix}/Morpheus.app /Applications/Morpheus-#{self.class.head.specs[:branch]}.app

        For more information about this branch, visit: https://gitlab.com/morpheus.lab/morpheus/-/tree/#{self.class.head.specs[:branch]}
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
