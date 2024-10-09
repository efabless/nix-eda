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
{
  lib,
  fetchFromGitHub,
  yosys,
  libedit,
  libbsd,
  bitwuzla,
  zlib,
  yosys-sby,
  python3,
  makeBinaryWrapper,
  version ? "0.46",
  sha256 ? "sha256-66CKhz5ds2Ywmh6lNSU6a0SMGWKmh0fn3795m/A05ow=",
}: let
  py3env = python3.withPackages (ps:
    with ps; [
      click
    ]);
in
  yosys.stdenv.mkDerivation (finalAttrs: {
    name = "yosys-eqy";

    dylibs = [
      "eqy_combine"
      "eqy_partition"
      "eqy_recode"
    ];

    src = fetchFromGitHub {
      owner = "yosyshq";
      repo = "eqy";
      rev = "yosys-${version}";
      inherit sha256;
    };

    makeFlags = [
      "YOSYS_CONFIG=${yosys}/bin/yosys-config"
    ];
    
    nativeBuildInputs = [
      makeBinaryWrapper
    ];

    buildInputs = [
      yosys
      libedit
      libbsd
      bitwuzla
      zlib
      yosys-sby
      py3env
    ];

    preConfigure = ''
      sed -i.bak "s@/usr/local@$out@" Makefile
      sed -i.bak "s@#!/usr/bin/env python3@#!${py3env}/bin/python3@" src/eqy.py
      sed -i.bak "s@\"/usr/bin/env\", @@" src/eqy_job.py
    '';

    postInstall = ''
      cp examples/spm/formal_pdk_proc.py $out/bin/eqy.formal_pdk_proc
      chmod +x $out/bin/eqy.formal_pdk_proc
    '';

    checkPhase = ''
      runHook preCheck
      sed -i.bak "s@> /dev/null@@" tests/python/Makefile
      sed -i.bak "s/@//" tests/python/Makefile
      sed -i.bak "s@make -C /tmp/@make -C \$(TMPDIR)@" tests/python/Makefile
      make -C tests/python clean "EQY=${py3env}/bin/python3 $PWD/src/eqy.py"
      make -C tests/python "EQY=${py3env}/bin/python3 $PWD/src/eqy.py"
      runHook postCheck
    '';
    
    fixupPhase = ''
      runHook preFixup
      mv $out/bin/eqy $out/bin/.eqy-wrapped
      makeWrapper ${py3env}/bin/python3 $out/bin/eqy\
        --add-flags "$out/bin/.eqy-wrapped"\
        --prefix PATH : ${lib.makeBinPath finalAttrs.buildInputs}
      runHook postFixup
    '';

    doCheck = false;

    meta = with lib; {
      description = "A front-end driver program for Yosys-based formal hardware verification flows.";
      homepage = "https://github.com/yosysHQ/eqy";
      mainProgram = "eqy";
      license = licenses.mit;
      platforms = platforms.linux ++ platforms.darwin;
    };
  })
