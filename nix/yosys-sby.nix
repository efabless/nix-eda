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
  yosys,
  fetchFromGitHub,
  python3,
  boolector,
  z3,
  yices,
  version ? "0.44",
  sha256 ? "sha256-/oDbbdZuWPdg0Xrh+c4i283vML9QTfyWVu8kryb4WaE=",
}: let
  py3env = python3.withPackages (ps:
    with ps; [
      click
    ]);
in
  yosys.stdenv.mkDerivation (finalAttrs: {
    name = "yosys-sby";
    dylibs = [];

    src = fetchFromGitHub {
      owner = "yosyshq";
      repo = "sby";
      rev = "yosys-${version}";
      inherit sha256;
    };

    makeFlags = [
      "YOSYS_CONFIG=${yosys}/bin/yosys-config"
    ];

    buildInputs = [
      yosys

      py3env
      # solvers
      boolector
      z3
      yices
    ];

    preConfigure = ''
      sed -i.bak "s@/usr/local@$out@" Makefile
      sed -i.bak "s@#!/usr/bin/env python3@#!${py3env}/bin/python3@" sbysrc/sby.py
      sed -i.bak "s@\"/usr/bin/env\", @@" sbysrc/sby_core.py
    '';

    checkPhase = ''
      make test
    '';

    doCheck = false;

    makeWrapperArgs = [
      "--prefix PATH : ${lib.makeBinPath finalAttrs.buildInputs}"
    ];

    meta = with lib; {
      description = "SymbiYosys (sby) -- Front-end for Yosys-based formal verification flows";
      homepage = "https://github.com/YosysHQ/sby";
      mainProgram = "sby";
      license = licenses.mit;
      platforms = platforms.linux ++ platforms.darwin;
    };
  })
