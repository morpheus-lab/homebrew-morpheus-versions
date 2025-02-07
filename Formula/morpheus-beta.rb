class MorpheusBeta < Formula
  desc "Modeling environment for multi-cellular systems biology"
  homepage "https://morpheus.gitlab.io/"
  url "https://datashare.tu-dresden.de/s/wJPG9EnxRfXBPEb/download/morpheus-advection-diffusion-release.tar.gz"
  version "3.0.0b1"
  sha256 "a533a2ee7a81193e103a8d609e9ed7ba6480135a7a1f5c8bf5424694fe6b0c7d"
  license "BSD-3-Clause"
  revision 1

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+(?:_?\d+)?)$/i)
  end

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
  depends_on "xtensor"
  depends_on "ffmpeg" => :recommended # Runtime dependencies

  uses_from_macos "bzip2"
  uses_from_macos "libxml2"
  uses_from_macos "zlib"

  resource "ginkgo" do
    url "https://github.com/ginkgo-project/ginkgo/archive/refs/tags/v1.8.0.tar.gz"
    sha256 "421efaed1be2ef11d230b79fc68bcf7e264a2c57ae52aff6dec7bd90f8d4ae30"
  end

  resource "xtensor-blas" do
    url "https://github.com/xtensor-stack/xtensor-blas/archive/refs/tags/0.21.0.tar.gz"
    sha256 "89ce6eceb47018f3b557945468502593e0bf0e5a816548aad8ac22247c8198b1"
  end

  # Patch to disable FetchContent in 3rdparty/ginkgo/CMakeLists.txt and 3rdparty/xtensor/CMakeLists.txt
  patch :DATA

  def install
    resource("ginkgo").stage do
      mkdir "build" do
        system "cmake", "-S", "..", "-B", ".",
             "-DBUILD_SHARED_LIBS=OFF",
             "-DGINKGO_BUILD_TESTS=OFF",
             "-DGINKGO_BUILD_MPI=OFF",
             "-DGINKGO_BUILD_CUDA=OFF",
             "-DGINKGO_BUILD_HIP=OFF",
             "-DGINKGO_BUILD_SYCL=OFF",
             "-DGINKGO_BUILD_EXAMPLES=OFF",
             "-DGINKGO_BUILD_BENCHMARKS=OFF",
             "-DGINKGO_BUILD_OMP=ON",
             *std_cmake_args
        system "cmake", "--build", "."
        system "cmake", "--install", ".", "--prefix=#{buildpath}/ginkgo"
      end
    end

    resource("xtensor-blas").stage do
      mkdir "build" do
        system "cmake", "-S", "..", "-B", ".",
               "-DCMAKE_INSTALL_PREFIX=#{buildpath}/xtensor-blas",
               "-DXTENSOR_USE_OPENMP=ON",
               "-DBUILD_SHARED_LIBS=OFF",
               "-DBUILD_TESTS=OFF",
               *std_cmake_args
        system "cmake", "--build", "."
        system "cmake", "--install", ".", "--prefix=#{buildpath}/xtensor-blas"
      end
    end

    args = [
      "-G Ninja", # Has to build with Ninja until: https://gitlab.kitware.com/cmake/cmake/-/issues/25142
      "-DMORPHEUS_BINARY_SUFFIX=#{version}", # Append release version to binary name
    ]

    if OS.mac?
      args << "-DMORPHEUS_RELEASE_BUNDLE=ON"
      args << "-DBREW_FORMULA_DEPLOYMENT=ON"

      # SBML import currently disabled by default due to libSBML build errors with some macOS SDKs
      args << "-DMORPHEUS_SBML=OFF" if build.without? "sbml"

      # Use Ginkgo and xtensor-blas from resources
      args << "-DGinkgo_DIR=#{buildpath}/ginkgo/lib/cmake/Ginkgo"
      args << "-DCMAKE_CXX_FLAGS=-I#{buildpath}/xtensor-blas/include"
    end

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    return unless OS.mac?

    bin.install_symlink prefix/"Morpheus.app/Contents/MacOS/morpheus-#{version}" => "morpheus"
    bin.install_symlink prefix/"Morpheus.app/Contents/MacOS/morpheus-#{version}-gui" => "morpheus-gui"

    # Set PATH environment variable including Homebrew prefix in macOS app bundle
    inreplace "#{prefix}/Morpheus.app/Contents/Info.plist", "HOMEBREW_BIN_PATH", "#{HOMEBREW_PREFIX}/bin"
  end

  def caveats
    on_macos do
      <<~EOS
        To start the Morpheus GUI, type the following command:

          morpheus-gui

        Or add Morpheus to your Applications folder with:

          ln -sf #{opt_prefix}/Morpheus.app /Applications/Morpheus-Beta.app

        For more information about this release, visit: https://morpheus.gitlab.io/download/latest/
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

__END__
diff --git a/3rdparty/ginkgo/CMakeLists.txt b/3rdparty/ginkgo/CMakeLists.txt
index fb5c2df4..62283a83 100644
--- a/3rdparty/ginkgo/CMakeLists.txt
+++ b/3rdparty/ginkgo/CMakeLists.txt
@@ -27,4 +27,5 @@ FetchContent_Declare(
 	# FIND_PACKAGE_ARGS NAMES ginkgo
 )
 
-FETCHCONTENT_MAKEAVAILABLE(ginkgo)
+# FETCHCONTENT_MAKEAVAILABLE(ginkgo)
+find_package(Ginkgo REQUIRED)
diff --git a/3rdparty/xtensor/CMakeLists.txt b/3rdparty/xtensor/CMakeLists.txt
index fdc19a58..2eea2001 100644
--- a/3rdparty/xtensor/CMakeLists.txt
+++ b/3rdparty/xtensor/CMakeLists.txt
@@ -51,16 +51,14 @@ FetchContent_Declare(
 	FIND_PACKAGE_ARGS NAMES xtensor-blas
 )
 
-FETCHCONTENT_MAKEAVAILABLE(xtl xsimd xtensor xtensor-blas)
+# FETCHCONTENT_MAKEAVAILABLE(xtl xsimd xtensor xtensor-blas)
 
-target_link_libraries( xtensor INTERFACE xsimd xtl xtensor-blas)
-target_compile_definitions( xtensor INTERFACE XTENSOR_USE_XSIMD=1 )
 # SET(BLAS_VENDOR "OpenBLAS")
 FIND_PACKAGE(BLAS REQUIRED)
 FIND_PACKAGE(LAPACK REQUIRED)
-target_compile_definitions( xtensor-blas INTERFACE HAVE_BLAS=1 )
-target_link_libraries( xtensor-blas INTERFACE BLAS::BLAS LAPACK::LAPACK)
+add_compile_definitions(HAVE_BLAS=1)
+link_libraries(BLAS::BLAS LAPACK::LAPACK)
 if(MORPHEUS_STATIC_BUILD)
 	# target_link_libraries(xtensor-blas INTERFACE /usr/lib/gcc/x86_64-linux-gnu/14/libgfortran.a)
-	target_link_libraries(xtensor-blas INTERFACE -lgfortran )
+	link_libraries(xtensor-blas INTERFACE -lgfortran )
 endif()
