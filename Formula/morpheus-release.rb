class MorpheusRelease < Formula
  desc "Modeling environment for multi-cellular systems biology"
  homepage "https://morpheus.gitlab.io/"
  license "BSD-3-Clause"
  head "https://gitlab.com/morpheus.lab/morpheus.git", branch: "release_2.4"

  option "with-sbml", "Enable SBML import via the internal libSBML build"

  depends_on "boost" => :build
  depends_on "cmake" => :build
  depends_on "doxygen" => :build
  depends_on "ninja" => :build
  depends_on "gnuplot"
  depends_on "graphviz"
  depends_on "libtiff"
  depends_on "qt@5.15.17"
  depends_on "ffmpeg" => :recommended # Runtime dependencies

  uses_from_macos "bzip2"
  uses_from_macos "libxml2"
  uses_from_macos "zlib"

  on_macos do
    depends_on "libomp"
  end

  resource "xtensor" do
    url "https://github.com/xtensor-stack/xtensor/archive/refs/tags/0.27.0.tar.gz"
    sha256 "9ca1743048492edfcc841bbe01f58520ff9c595ec587c0e7dc2fc39deeef3e04"
  end

  resource "xsimd" do
    url "https://github.com/xtensor-stack/xsimd/archive/refs/tags/13.2.0.tar.gz"
    sha256 "edd8cd3d548c185adc70321c53c36df41abe64c1fe2c67bc6d93c3ecda82447a"
  end

  resource "xtl" do
    url "https://github.com/xtensor-stack/xtl/archive/refs/tags/0.8.0.tar.gz"
    sha256 "ee38153b7dd0ec84cee3361f5488a4e7e6ddd26392612ac8821cbc76e740273a"
  end

  def install
    resource("xtl").stage do
      mkdir "build" do
        system "cmake", "-S", "..", "-B", ".",
               "-DBUILD_TESTS=OFF",
               *std_cmake_args(install_prefix: buildpath.to_s)
        system "cmake", "--build", "."
        system "cmake", "--install", "."
      end
    end

    resource("xsimd").stage do
      mkdir "build" do
        system "cmake", "-S", "..", "-B", ".",
               "-DBUILD_TESTS=OFF",
               *std_cmake_args(install_prefix: buildpath.to_s)
        system "cmake", "--build", "."
        system "cmake", "--install", "."
      end
    end

    resource("xtensor").stage do
      mkdir "build" do
        system "cmake", "-S", "..", "-B", ".",
               "-DXTENSOR_USE_OPENMP=ON",
               "-DXTENSOR_USE_SIMD=ON",
               "-DBUILD_TESTS=OFF",
               *std_cmake_args(install_prefix: buildpath.to_s)
        system "cmake", "--build", "."
        system "cmake", "--install", "."
      end
    end

    # Avoid statically linking to Boost libraries when `-DBUILD_TESTING=OFF`
    cmakelists = ["CMakeLists.txt", "morpheus/CMakeLists.txt"]
    inreplace cmakelists, "set(Boost_USE_STATIC_LIBS ON)", "set(Boost_USE_STATIC_LIBS OFF)"

    # Workaround for newer Clang
    # error: a template argument list is expected after a name prefixed by the template keyword
    ENV.append_to_cflags "-Wno-missing-template-arg-list-after-template-kw" if OS.mac?

    # use branch name and Git commit hash as binary suffix
    binary_suffix = "#{self.class.head.specs[:branch]}-#{`git rev-parse HEAD`.strip[0, 7]}"

    args = [
      "-G",
      "Ninja", # has to build with Ninja until: https://gitlab.kitware.com/cmake/cmake/-/issues/25142
      "-DMORPHEUS_BINARY_SUFFIX=#{binary_suffix}",
      "-DCMAKE_PREFIX_PATH=#{buildpath}/resources",
    ]

    if OS.mac?
      args << "-DMORPHEUS_RELEASE_BUNDLE=ON"
      args << "-DBREW_FORMULA_DEPLOYMENT=ON"

      # SBML import currently disabled by default due to libSBML build errors with some macOS SDKs
      args << "-DMORPHEUS_SBML=OFF" if build.without? "sbml"
    end

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    return unless OS.mac?

    bin.install_symlink "#{prefix}/Morpheus.app/Contents/MacOS/morpheus-#{binary_suffix}" => "morpheus"
    bin.install_symlink "#{prefix}/Morpheus.app/Contents/MacOS/morpheus-#{binary_suffix}-gui" => "morpheus-gui"

    # Set PATH environment variable including Homebrew prefix in macOS app bundle
    inreplace "#{prefix}/Morpheus.app/Contents/Info.plist", "HOMEBREW_BIN_PATH", "#{HOMEBREW_PREFIX}/bin"
  end

  def post_install
    # Sign to ensure proper execution of the app bundle
    system "/usr/bin/codesign", "-f", "-s", "-", "--deep", "#{prefix}/Morpheus.app" if OS.mac?
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
    (testpath/"test.xml").write <<~XML
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
    XML

    assert_match "Simulation finished", shell_output("#{bin}/morpheus --file test.xml")
  end
end
