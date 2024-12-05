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
  surelog,
  capnproto,
  antlr4,
  pkg-config,
  writeText,
  rev ? "fd4b2bd9510c02c4cf42f8c4c6468c5c0a7dd9e6",
  rev-date ? "2024-08-07",
  sha256 ? "sha256-yj+SBq6PqgPBcgz2zHZ9AUppllG/dqetU7lWPkFC+iE=",
}: let
  yosys-mk = writeText "yosys-mk" ''
    t  := yosys
    ts := ''$(call GetTargetStructName,''${t})

    ''${ts}.src_dir         := ''$(shell yosys-config --datdir/include)
    ''${ts}.mod_dir         := ''${TOP_DIR}third_party/yosys_mod/
  '';
in
  yosys.stdenv.mkDerivation (finalAttrs: {
    pname = "yosys-synlig-sv";
    version = rev-date;
    
    dylibs = ["synlig-sv"];

    src = fetchFromGitHub {
      owner = "chipsalliance";
      repo = "synlig";
      inherit rev;
      inherit sha256;
    };

    buildInputs = [
      yosys
      surelog
      capnproto
      antlr4.runtime.cpp
    ];

    nativeBuildInputs = [
      pkg-config
    ];

    postPatch = ''
      sed -i 's/AST::process(design, current_ast,/AST::process(design, current_ast, false,/' frontends/systemverilog/uhdm_common_frontend.cc
      rm third_party/Build.surelog.mk
      cp ${yosys-mk} third_party/Build.yosys.mk
    '';

    buildPhase = ''
      make build@systemverilog-plugin\
        -j$NIX_BUILD_CORES\
        LDFLAGS="''$(yosys-config --ldflags)"
    '';

    installPhase = ''
      mkdir -p $out/share/yosys/plugins
      mv build/release/systemverilog-plugin/systemverilog.so $out/share/yosys/plugins/synlig-sv.so
    '';

    makeWrapperArgs = [
      "--prefix PATH : ${lib.makeBinPath finalAttrs.buildInputs}"
    ];

    meta = with lib; {
      description = "SystemVerilog and UHDM front end plugin for Yosys";
      homepage = "https://github.com/chipsalliance/synlig";
      license = licenses.asl20;
      platforms = platforms.linux ++ platforms.darwin;
    };
  })
