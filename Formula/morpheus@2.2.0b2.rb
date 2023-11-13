class MorpheusAT220b2 < Formula
  desc "Modelling environment for Multi-Cellular Systems Biology"
  homepage "https://morpheus.gitlab.io"
  url "https://gitlab.com/morpheus.lab/morpheus/-/archive/v2.2.0-beta2/morpheus-v2.2.0-beta2.tar.gz"
  version "2.2.0b2"
  sha256 "b99b8cba61d206c084882f066d04914cee03eab706e55f3c161445f8d929d981"
  license "BSD-3-Clause"

  depends_on "boost" => :build
  depends_on "cmake" => :build
  depends_on "doxygen" => :build
  depends_on "gnuplot" # Runtime dependencies
  #   depends_on "graphviz"
  depends_on "libtiff"
  depends_on "qt"
  depends_on "libomp" => :recommended

  uses_from_macos "bzip2"
  uses_from_macos "libxml2"
  uses_from_macos "zlib"

  def install
    system "cmake", ".", *std_cmake_args
    system "make", "install"
  end

  def caveats
    <<~EOS
      To start Morpheus, type the following command:

        morpheus-gui

      For more information about this version visit:
      https://morpheus.gitlab.io/download/v#{version}/

    EOS
  end
end
