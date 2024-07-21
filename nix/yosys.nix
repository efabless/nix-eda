# Copyright 2023 Efabless Corporation
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
#
# Code adapated from Nixpkgs, original license follows:
# ---
# Copyright (c) 2003-2023 Eelco Dolstra and the Nixpkgs/NixOS contributors
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
{
  symlinkJoin,
  boost185,
  python3,
  lib,
  makeWrapper,
  clangStdenv,
  fetchFromGitHub,
  pkg-config,
  bison,
  flex,
  yosys-abc,
  tcl,
  libedit,
  libbsd,
  libffi,
  zlib,
  version ? "0.38",
  rev ? "543faed9c8cd7c33bbb407577d56e4b7444ba61c",
  sha256 ? "sha256-mzMBhnIEgToez6mGFOvO7zBA+rNivZ9OnLQsjBBDamA=",
}: let
  boost-python = boost185.override {
    python = python3;
    enablePython = true;
  };
  self = clangStdenv.mkDerivation {
    name = "yosys";
    inherit version;

    src = fetchFromGitHub {
      owner = "YosysHQ";
      repo = "yosys";
      inherit rev;
      inherit sha256;
    };

    nativeBuildInputs = [pkg-config bison flex];
    propagatedBuildInputs = [
      yosys-abc
      python3
      tcl
      libedit
      libbsd
      libffi
      zlib
      boost185
    ];

    passthru = {
      pythonModule = python3.pkgs.toPythonModule (clangStdenv.mkDerivation {
        name = "${python3.name}-pyosys";
        buildInputs = [self];
        unpackPhase = "true";
        installPhase = ''
          mkdir -p $out/${python3.sitePackages}
          ln -s ${self}/${python3.sitePackages}/pyosys $out/${python3.sitePackages}/pyosys
          mkdir -p $out/${python3.sitePackages}/pyosys-${version}.dist-info
          sed 's/%VERSION%/${version}/' ${./supporting/yosys/PKG-INFO} > $out/${python3.sitePackages}/pyosys-${version}.dist-info/PKG-INFO
          echo "pyosys" > $out/${python3.sitePackages}/pyosys-${version}.dist-info/top_level.txt
        '';
        meta = with lib; {
          description = "Python API access to Yosys";
          license = with licenses; [mit];
          homepage = "https://yosyshq.com/";
          platforms = platforms.all;
        };
      });
    };

    patches = [
      ./patches/yosys/fix-clang-build.patch
      ./patches/yosys/new-bitwuzla.patch
      ./patches/yosys/plugin-search-dirs.patch
      ./patches/yosys/makefile.patch
    ];

    postPatch = ''
      substituteInPlace ./Makefile \
        --replace 'echo UNKNOWN' 'echo ${builtins.substring 0 10 rev}'

      chmod +x ./misc/yosys-config.in
      patchShebangs tests ./misc/yosys-config.in
      sed -Ei "s@PYTHON_DESTDIR := .+@PYTHON_DESTDIR=${placeholder "out"}/${python3.sitePackages}@" ./Makefile
      sed -Ei 's@^BOOST_PYTHON_LIB .+@BOOST_PYTHON_LIB := ${boost-python}/lib/libboost_${python3.pythonAttr}${clangStdenv.hostPlatform.extensions.sharedLibrary}@' ./Makefile
    '';

    preConfigure = let
      shortAbcRev = builtins.substring 0 7 yosys-abc.rev;
    in ''
      chmod -R u+w .
      make config-clang

      echo 'ABCEXTERNAL = ${yosys-abc}/bin/abc' >> Makefile.conf

      if ! grep -q "ABCREV = ${shortAbcRev}" Makefile; then
        echo "ERROR: yosys isn't compatible with the provided abc (${yosys-abc}), failing."
        exit 1
      fi
    '';
    makeFlags = ["PREFIX=${placeholder "out"}"];

    postBuild = "ln -sfv ${yosys-abc}/bin/abc ./yosys-abc";
    postInstall = "ln -sfv ${yosys-abc}/bin/abc $out/bin/yosys-abc";

    doCheck = false;
    enableParallelBuilding = true;

    meta = with lib; {
      description = "Yosys Open SYnthesis Suite";
      license = with licenses; [mit];
      homepage = "https://www.yosyshq.com/";
      platforms = platforms.all;
    };
  };
  withPlugins = plugins: let
    paths = lib.closePropagation plugins;
    dylibs = lib.lists.flatten (map (n: n.dylibs) plugins);
  in let
    module_flags = with builtins;
      concatStringsSep " "
      (map (so: "--add-flags -m --add-flags ${so}") dylibs);
  in (symlinkJoin {
    name = "${self.name}-with-plugins";
    paths = paths ++ [self];
    nativeBuildInputs = [makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/yosys \
        --set NIX_YOSYS_PLUGIN_DIRS $out/share/yosys/plugins \
        ${module_flags}
    '';
  });
in
  self
