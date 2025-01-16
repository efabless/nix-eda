# Copyright 2024 Efabless Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
{
  stdenv,
  fetchFromGitHub,
  fetchgit,
  lib,
  autoconf,
  automake,
  bison,
  blas,
  flex,
  fftw,
  gfortran,
  lapack,
  libtool_2,
  mpi,
  suitesparse,
  trilinos,
  withMPI ? false,
  # for doc
  texliveMedium,
  enableDocs ? true,
  # for tests
  bash,
  bc,
  openssh, # required by MPI
  perl,
  python3,
  enableTests ? true,
  version ? "7.8.0",
  sha256 ? "sha256-+aNy2bGuFQ517FZUvU0YqN0gmChRpVuFEmFGTCx9AgY=",
  regression-sha256 ? "sha256-Fxi/NpXXIw/bseWaLi2iQ4sg4S9Z+othGgSvQoxyJ9c=",
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "xyce";
  inherit version;

  # Using fetchurl or fetchFromGitHub doesn't include the manuals
  # due to .gitattributes files
  xyce_src = fetchgit {
    name = "xyce_src_${version}";
    url = "https://github.com/Xyce/Xyce.git";
    rev = "Release-${version}";
    inherit sha256;
  };

  regression_src = fetchFromGitHub {
    name = "xyce_regression_src_${version}";
    owner = "Xyce";
    repo = "Xyce_Regression";
    rev = "Release-${version}";
    sha256 = regression-sha256;
  };

  srcs = [finalAttrs.xyce_src finalAttrs.regression_src];

  sourceRoot = finalAttrs.xyce_src.name;

  preConfigure = "./bootstrap";

  configureFlags =
    [
      "CXXFLAGS=-O3"
      "--enable-xyce-shareable"
      "--enable-shared"
      "--enable-stokhos"
      "--enable-amesos2"
    ]
    ++ lib.optionals trilinos.withMPI [
      "--enable-mpi"
      "CXX=mpicxx"
      "CC=mpicc"
      "F77=mpif77"
    ];

  enableParallelBuilding = true;

  nativeBuildInputs =
    [
      autoconf
      automake
      gfortran
      libtool_2
    ]
    ++ lib.optionals enableDocs [
      (texliveMedium.withPackages (ps:
        with ps; [
          enumitem
          koma-script
          optional
          framed
          enumitem
          multirow
          newtx
          preprint
        ]))
    ];

  buildInputs =
    [
      bison
      blas
      flex
      fftw
      lapack
      suitesparse
      trilinos
    ]
    ++ lib.optionals trilinos.withMPI [mpi];

  doCheck = enableTests;

  postPatch = ''
    pushd ../${finalAttrs.regression_src.name}
    find Netlists -type f -regex ".*\.sh\|.*\.pl" -exec chmod ugo+x {} \;
    # some tests generate new files, some overwrite netlists
    find . -type d -exec chmod u+w {} \;
    find . -type f -name "*.cir" -exec chmod u+w {} \;
    patchShebangs Netlists/ TestScripts/
    # patch script generating functions
    sed -i -E 's|/usr/bin/env perl|${lib.escapeRegex perl.outPath}/bin/perl|'  \
      TestScripts/XyceRegression/Testing/Netlists/RunOptions/runOptions.cir.sh
    sed -i -E 's|/bin/sh|${lib.escapeRegex bash.outPath}/bin/sh|' \
      TestScripts/XyceRegression/Testing/Netlists/RunOptions/runOptions.cir.sh
    popd
  '';

  nativeCheckInputs =
    [
      bc
      perl
      (python3.withPackages (ps: with ps; [numpy scipy]))
    ]
    ++ lib.optionals trilinos.withMPI [mpi openssh];

  checkPhase = ''
    XYCE_BINARY="$(pwd)/src/Xyce"
    EXECSTRING="${lib.optionalString trilinos.withMPI "mpirun -np 2 "}$XYCE_BINARY"
    TEST_ROOT="$(pwd)/../${finalAttrs.regression_src.name}"

    # Honor the TMP variable
    sed -i -E 's|/tmp|\$TMP|' $TEST_ROOT/TestScripts/suggestXyceTagList.sh

    EXLUDE_TESTS_FILE=$TMP/exclude_tests.$$
    # Gold standard has additional ":R" suffix in result column label
    echo "Output/HB/hb-step-tecplot.cir" >> $EXLUDE_TESTS_FILE
    # This test makes Xyce access /sys/class/net when run with MPI
    ${lib.optionalString withMPI "echo \"CommandLine/command_line.cir\" >> $EXLUDE_TESTS_FILE"}

    $TEST_ROOT/TestScripts/run_xyce_regression \
      --output="$(pwd)/Xyce_Test" \
      --xyce_test="''${TEST_ROOT}" \
      --taglist="$($TEST_ROOT/TestScripts/suggestXyceTagList.sh "$XYCE_BINARY" | sed -E -e 's/TAGLIST=([^ ]+).*/\1/' -e '2,$d')" \
      --resultfile="$(pwd)/test_results" \
      --excludelist="$EXLUDE_TESTS_FILE" \
      "''${EXECSTRING}"
  '';

  outputs = ["out" "doc"];

  postInstall = lib.optionalString enableDocs ''
    local docFiles=("doc/Users_Guide/Xyce_UG"
      "doc/Reference_Guide/Xyce_RG"
      "doc/Release_Notes/Release_Notes_${lib.versions.majorMinor version}/Release_Notes_${lib.versions.majorMinor version}")

    # SANDIA LaTeX class and some organization logos are not publicly available see
    # https://groups.google.com/g/xyce-users/c/MxeViRo8CT4/m/ppCY7ePLEAAJ
    for img in "snllineblubrd" "snllineblk" "DOEbwlogo" "NNSA_logo"; do
      sed -i -E "s/\\includegraphics\[height=(0.[1-9]in)\]\{$img\}/\\mbox\{\\rule\{0mm\}\{\1\}\}/" ''${docFiles[2]}.tex
    done

    install -d $doc/share/doc/${finalAttrs.pname}-${version}/
    for d in ''${docFiles[@]}; do
      # Use a public document class
      sed -i -E 's/\\documentclass\[11pt,report\]\{SANDreport\}/\\documentclass\[11pt,letterpaper\]\{scrreprt\}/' $d.tex
      sed -i -E 's/\\usepackage\[sand\]\{optional\}/\\usepackage\[report\]\{optional\}/' $d.tex
      pushd $(dirname $d)
      make
      install -t $doc/share/doc/${finalAttrs.pname}-${version}/ $(basename $d.pdf)
      popd
    done
  '';

  meta = {
    description = "High-performance analog circuit simulator";
    longDescription = ''
      Xyce is a SPICE-compatible, high-performance analog circuit simulator,
      capable of solving extremely large circuit problems by supporting
      large-scale parallel computing platforms.
    '';
    homepage = "https://xyce.sandia.gov";
    license = lib.licenses.gpl3;
    broken = stdenv.hostPlatform.isDarwin;
    platforms = lib.platforms.unix;
  };
})
