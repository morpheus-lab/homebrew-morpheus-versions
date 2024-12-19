class MorpheusBeta < Formula
  desc "Modeling environment for multi-cellular systems biology"
  homepage "https://morpheus.gitlab.io/"
  url "https://datashare.tu-dresden.de/s/wJPG9EnxRfXBPEb/download/morpheus-advection-diffusion-release.tar.gz"
  version "3.3.0b1"
  sha256 "a533a2ee7a81193e103a8d609e9ed7ba6480135a7a1f5c8bf5424694fe6b0c7d"
  license "BSD-3-Clause"

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
  # depends_on "nlohmann-json"
  # depends_on "openblas"
  depends_on "qt@6"
  depends_on "xsimd"
  depends_on "xtensor"
  depends_on "ffmpeg" => :recommended # Runtime dependencies

  uses_from_macos "bzip2"
  uses_from_macos "libxml2"
  uses_from_macos "zlib"

  # Add Ginkgo as a resource
  resource "ginkgo" do
    url "https://github.com/ginkgo-project/ginkgo/archive/refs/tags/v1.8.0.tar.gz"
    sha256 "421efaed1be2ef11d230b79fc68bcf7e264a2c57ae52aff6dec7bd90f8d4ae30"
  end

  resource "xtensor-blas" do
    url "https://github.com/xtensor-stack/xtensor-blas/archive/refs/tags/0.21.0.tar.gz"
    sha256 "89ce6eceb47018f3b557945468502593e0bf0e5a816548aad8ac22247c8198b1"
  end

  # Patch to disable FetchContent in 3rdparty/ginkgo/CMakeLists.txt
  patch :DATA

  def install
    # Fetch and build Ginkgo manually
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

    # has to build with Ninja until: https://gitlab.kitware.com/cmake/cmake/-/issues/25142
    args = ["-G Ninja"]

    if OS.mac?
      args << "-DMORPHEUS_RELEASE_BUNDLE=ON"
      args << "-DBREW_FORMULA_DEPLOYMENT=ON"

      # SBML import currently disabled by default due to libSBML build errors with some macOS SDKs
      args << "-DMORPHEUS_SBML=OFF" if build.without? "sbml"

      # args << "-DHOMEBREW_ALLOW_FETCHCONTENT=ON"
      args << "-DGINKGO_ROOT=#{buildpath}/ginkgo"
      args << "-DGinkgo_DIR=#{buildpath}/ginkgo/lib/cmake/Ginkgo"
      # args << "-Dxtensor_DIR=#{Formula["xtensor"].opt_lib}/cmake/xtensor"
      # args << "-Dxsimd_DIR=#{Formula["xsimd"].opt_lib}/cmake/xsimd"
      args << "-Dxtensor-blas_DIR=#{buildpath}/xtensor-blas/lib/cmake/xtensor-blas"
      args << "-DCMAKE_CXX_FLAGS=-I#{buildpath}/xtensor-blas/include"
      # args << "-DOpenMP_CXX_FLAGS=-I#{Formula["libomp"].opt_include}"
      # args << "-DOpenMP_CXX_LIBRARIES=#{Formula["libomp"].opt_lib}/libomp.dylib"
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

          ln -sf #{opt_prefix}/Morpheus.app /Applications

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
index fb5c2df4..4d3a3e42 100644
--- a/3rdparty/ginkgo/CMakeLists.txt
+++ b/3rdparty/ginkgo/CMakeLists.txt
@@ -16,15 +16,5 @@ set(GINKGO_BUILD_EXAMPLES OFF CACHE INTERNAL "")
 set(GINKGO_BUILD_BENCHMARKS OFF CACHE INTERNAL "")
 set(GINKGO_BUILD_OMP     ON CACHE INTERNAL "")
 
-MESSAGE(STATUS "Fetching Ginkgo ...")
-FetchContent_Declare(
-	ginkgo
-	GIT_REPOSITORY https://github.com/ginkgo-project/ginkgo.git
-	GIT_TAG        v1.8.0
-	GIT_SHALLOW TRUE
-	GIT_PROGRESS TRUE
-	UPDATE_DISCONNECTED 1
-	# FIND_PACKAGE_ARGS NAMES ginkgo
-)
-
-FETCHCONTENT_MAKEAVAILABLE(ginkgo)
+# Use prebuilt Ginkgo from the system
+find_package(Ginkgo REQUIRED)
diff --git a/3rdparty/xtensor/CMakeLists.txt b/3rdparty/xtensor/CMakeLists.txt
index fdc19a58..4c9cd292 100644
--- a/3rdparty/xtensor/CMakeLists.txt
+++ b/3rdparty/xtensor/CMakeLists.txt
@@ -9,58 +9,16 @@ if ( NOT DEFINED PROJECT_SOURCE_DIR)
 	SET(XTENSOR_USE_OPENMP ON CACHE BOOL "")
 endif ()
 
+# Include directories and compile definitions for xtensor and dependencies
+include_directories(${CMAKE_INSTALL_PREFIX}/include)
+add_compile_definitions(XTENSOR_USE_XSIMD=1)
 
-MESSAGE(STATUS "Fetching xtensor ...")
-FetchContent_Declare(
-	xtl
-	GIT_REPOSITORY https://github.com/xtensor-stack/xtl.git
-	GIT_TAG        0.7.7
-	GIT_SHALLOW TRUE
-	GIT_PROGRESS TRUE
-	UPDATE_DISCONNECTED 1
-	FIND_PACKAGE_ARGS NAMES xtl
-)
-FetchContent_Declare(
-	xsimd
-	GIT_REPOSITORY https://github.com/xtensor-stack/xsimd.git
-	GIT_TAG        13.0.0
-	GIT_SHALLOW TRUE
-	GIT_PROGRESS TRUE
-	UPDATE_DISCONNECTED 1
-	FIND_PACKAGE_ARGS NAMES xsimd
-)
-FetchContent_Declare(
-	xtensor
-	GIT_REPOSITORY https://github.com/xtensor-stack/xtensor.git
-	GIT_TAG        0.25.0
-	GIT_SHALLOW TRUE
-	GIT_PROGRESS TRUE
-	PATCH_COMMAND git apply ${CMAKE_CURRENT_SOURCE_DIR}/xtensor_omp.patch
-	CMAKE_ARGS CMAKE_FIND_LIBRARY_SUFFIXES=${CMAKE_FIND_LIBRARY_SUFFIXES}
-	UPDATE_DISCONNECTED 1
-	FIND_PACKAGE_ARGS NAMES xtensor
-)
+# Link BLAS and LAPACK globally
+find_package(BLAS REQUIRED)
+find_package(LAPACK REQUIRED)
+add_compile_definitions(HAVE_BLAS=1)
+link_libraries(BLAS::BLAS LAPACK::LAPACK)
 
-FetchContent_Declare(
-	xtensor-blas
-	GIT_REPOSITORY https://github.com/xtensor-stack/xtensor-blas.git
-	GIT_TAG        0.21.0
-	GIT_SHALLOW TRUE
-	GIT_PROGRESS TRUE
-	UPDATE_DISCONNECTED 1
-	FIND_PACKAGE_ARGS NAMES xtensor-blas
-)
-
-FETCHCONTENT_MAKEAVAILABLE(xtl xsimd xtensor xtensor-blas)
-
-target_link_libraries( xtensor INTERFACE xsimd xtl xtensor-blas)
-target_compile_definitions( xtensor INTERFACE XTENSOR_USE_XSIMD=1 )
-# SET(BLAS_VENDOR "OpenBLAS")
-FIND_PACKAGE(BLAS REQUIRED)
-FIND_PACKAGE(LAPACK REQUIRED)
-target_compile_definitions( xtensor-blas INTERFACE HAVE_BLAS=1 )
-target_link_libraries( xtensor-blas INTERFACE BLAS::BLAS LAPACK::LAPACK)
 if(MORPHEUS_STATIC_BUILD)
-	# target_link_libraries(xtensor-blas INTERFACE /usr/lib/gcc/x86_64-linux-gnu/14/libgfortran.a)
-	target_link_libraries(xtensor-blas INTERFACE -lgfortran )
+    link_libraries(-lgfortran)
 endif()
