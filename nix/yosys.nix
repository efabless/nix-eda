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
  lib,
  symlinkJoin,
  clangStdenv,
  fetchFromGitHub,
  pkg-config,
  cmake,
  makeWrapper,
  boost185,
  python3,
  bison,
  flex,
  tcl,
  libedit,
  libbsd,
  libffi,
  zlib,
  fetchurl,
  bash,
  version ? "0.44",
  sha256 ? "sha256-Z8Nw+cfBZNW0s9WuLU1sdgfvFvADjG4XTLrPY8m5rMM=",
  abc-sha256 ? "sha256-zFFesCztTEyf+gg23XjGy5hXNjRwh011Ux33jnjsf90=",
}: let
  abc = clangStdenv.mkDerivation {
    name = "yosys-abc";

    src = fetchurl {
      url = "https://github.com/YosysHQ/yosys/releases/download/yosys-${version}/abc.tar.gz";
      sha256 = abc-sha256;
    };

    patches = [
      ./patches/yosys/abc-editline.patch
    ];

    postPatch = ''
      sed -i "s@-lreadline@-ledit@" ./Makefile
    '';

    nativeBuildInputs = [cmake];
    buildInputs = [libedit];

    installPhase = "mkdir -p $out/bin && mv abc $out/bin";
  };
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
      rev = "yosys-${version}";
      inherit sha256;
    };

    nativeBuildInputs = [pkg-config bison flex];
    propagatedBuildInputs = [
      tcl
      libedit
      libbsd
      libffi
      zlib
      boost185
    ];
    buildInputs = [
      python3
      abc
    ];

    passthru = {
      pyosys = python3.pkgs.toPythonModule (clangStdenv.mkDerivation {
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
      inherit withPlugins;
    };
    
    makeFlags = [
      "PRETTY=0"
      "PREFIX=${placeholder "out"}"
      "ENABLE_READLINE=0"
      "ENABLE_EDITLINE=1"
      "ENABLE_YOSYS=1"
      "ENABLE_PYOSYS=1"
      "ABCEXTERNAL=${abc}/bin/abc"
      "PYTHON_DESTDIR=${placeholder "out"}/${python3.sitePackages}"
      "BOOST_PYTHON_LIB=${boost-python}/lib/libboost_${python3.pythonAttr}${clangStdenv.hostPlatform.extensions.sharedLibrary}"
    ];

    patches = [
      ./patches/yosys/new-bitwuzla.patch
      ./patches/yosys/plugin-search-dirs.patch
      (fetchurl {
        url = "https://github.com/YosysHQ/yosys/pull/4553.patch";
        sha256 = "sha256-zXOxCFjrva4a2DoFBVkEoRLbtOYu7+Q8e6SekLUqu2c=";
      })
    ];

    postPatch = ''
      substituteInPlace ./Makefile \
        --replace 'echo UNKNOWN' 'echo ${version}'

      chmod +x ./misc/yosys-config.in
      set -x
    '';

    postBuild = "ln -sfv ${abc}/bin/abc ./yosys-abc";
    postInstall = "ln -sfv ${abc}/bin/abc $out/bin/yosys-abc";

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
      cat <<SCRIPT > $out/bin/with_yosys_plugin_env
      #!${bash}/bin/bash
      export NIX_YOSYS_PLUGIN_DIRS='$out/share/yosys/plugins'
      exec "\$@"
      SCRIPT
      chmod +x $out/bin/with_yosys_plugin_env
      wrapProgram $out/bin/yosys \
        --set NIX_YOSYS_PLUGIN_DIRS $out/share/yosys/plugins \
        ${module_flags}
    '';
  });
in
  self
