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
  nixConfig = {
    extra-substituters = [
      "https://openlane.cachix.org"
    ];
    extra-trusted-public-keys = [
      "openlane.cachix.org-1:qqdwh+QMNGmZAuyeQJTH9ErW57OWSvdtuwfBKdS254E="
    ];
  };

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixos-24.05;
  };
  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    lib = nixpkgs.lib;
  in {
    # Helper functions
    createDockerImage = import ./nix/create-docker.nix;
    buildPythonEnvForInterpreter = import ;
    composePythonOverlay = composable: pkgs': pkgs: {
      python3 = pkgs.python3.override {
        packageOverrides = pkgs'.pythonOverrides;
      };

      pythonOverrides =
        lib.composeExtensions (composable pkgs' pkgs)
        (
          if (builtins.hasAttr "pythonOverrides" pkgs)
          then pkgs.pythonOverrides
          else _: _: {}
        );
    };
    flakesToOverlay = flakes: (
      lib.composeManyExtensions (builtins.map
        (flake: _: pkgs: flake.packages."${pkgs.stdenv.system}")
        flakes)
    );
    forAllSystems = fn:
      lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ]
      fn;

    # Common
    overlays = {
      default = lib.composeManyExtensions [
        (
          pkgs': pkgs: {
            buildPythonEnvForInterpreter = (import ./nix/build-python-env-for-interpreter.nix) lib;
          }
        )
        (
          self.composePythonOverlay (pkgs': pkgs: pypkgs': pypkgs: let
            callPythonPackage = lib.callPackageWith (pkgs' // pkgs'.python3.pkgs);
          in {
            gdsfactory = callPythonPackage ./nix/gdsfactory.nix {};
          })
        )
        (pkgs': pkgs: let
          callPackage = lib.callPackageWith pkgs';
        in {
          # Dependencies
          ghdl-llvm = pkgs.ghdl-llvm.overrideAttrs (self: super: {
            meta.platforms = super.meta.platforms ++ ["x86_64-darwin"];
          });

          ## Cairo X11 on Mac
          cairo = pkgs.cairo.override {
            x11Support = true;
          };

          ## slightly worse floating point errors cause ONE of the tests to fail
          ## on x86_64-darwin
          qrupdate = pkgs.qrupdate.overrideAttrs (self: super: {
            doCheck = pkgs.system != "x86_64-darwin";
          });

          # Main
          magic = callPackage ./nix/magic.nix {};
          magic-vlsi = pkgs'.magic; # alias, there's a python package called magic
          netgen = callPackage ./nix/netgen.nix {};
          ngspice = callPackage ./nix/ngspice.nix {};
          klayout = callPackage ./nix/klayout.nix {};
          #
          klayout-gdsfactory = callPackage ./nix/klayout-gdsfactory.nix {
            inherit (pkgs'.python3.pkgs) gdsfactory;
          };
          surelog = callPackage ./nix/surelog.nix {};
          tclFull = callPackage ./nix/tclFull.nix {};
          tk-x11 = callPackage ./nix/tk-x11.nix {};
          verilator = callPackage ./nix/verilator.nix {};
          xschem = callPackage ./nix/xschem.nix {};
          bitwuzla = callPackage ./nix/bitwuzla.nix {};
          yosys = callPackage ./nix/yosys.nix {};
          yosys-sby = callPackage ./nix/yosys-sby.nix {};
          yosys-eqy = callPackage ./nix/yosys-eqy.nix {};
          yosys-f4pga-sdc = callPackage ./nix/yosys-f4pga-sdc.nix {};
          yosys-lighter = callPackage ./nix/yosys-lighter.nix {};
          yosys-synlig-sv = callPackage ./nix/yosys-synlig-sv.nix {};
          yosys-ghdl = callPackage ./nix/yosys-ghdl.nix {};
          yosysFull = pkgs'.yosys.withPlugins (with pkgs';
            [
              yosys-sby
              yosys-eqy
              yosys-f4pga-sdc
              yosys-lighter
              yosys-synlig-sv
            ]
            ++ lib.optionals pkgs.stdenv.isx86_64 [yosys-ghdl]);
        })
      ];
    };

    legacyPackages = self.forAllSystems (
      system:
        import nixpkgs {
          inherit system;
          overlays = [self.overlays.default];
        }
    );

    # Outputs
    packages = self.forAllSystems (
      system: {
        inherit (self.legacyPackages."${system}") magic magic-vlsi netgen klayout klayout-gdsfactory surelog tclfull tk-x11 verilator xschem bitwuzla yosys yosys-sby yosys-eqy yosys-f4pga-sdc yosys-lighter yosys-synlig-sv yosys-ghdl yosysFull;
        inherit (self.legacyPackages."${system}".python3.pkgs) gdsfactory;
      }
    );
  };
}
