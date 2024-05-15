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
    nixpkgs.url = github:nixos/nixpkgs/nixos-23.11;
  };
  outputs = {
    self,
    nixpkgs,
    ...
  }: {
    # Helper functions
    createDockerImage = import ./nix/create-docker.nix;
    forAllSystems = {
      current,
      withInputs ? [],
      overlays ? [],
    }: function:
      nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ] (
        system: let
          pkgs = import nixpkgs {
            inherit system;
            overlays =
              [
                (import ./nix/overlay.nix)
              ]
              ++ overlays;
          };
          inputPackageList = [pkgs] ++ (map (x: x.packages."${system}") withInputs);
          pythonPackageList = [pkgs pkgs.python3.pkgs] ++ (map (x: x.packages."${system}") withInputs);
          inputPkgs = (builtins.foldl' (acc: elem: acc // elem) {} inputPackageList);
          inputPythonPkgs = (builtins.foldl' (acc: elem: acc // elem) {} pythonPackageList);
          allPkgs = inputPkgs // current.packages."${system}";
          allPythonPkgs = inputPythonPkgs // current.packages."${system}";
        in
          function {
            inherit pkgs;
            inherit inputPkgs;
            inherit inputPythonPkgs;
            inherit allPkgs;
            inherit allPythonPkgs;
            callPackage = pkgs.lib.callPackageWith allPkgs;
            callPythonPackage = pkgs.lib.callPackageWith allPythonPkgs;
          }
      );

    # Outputs
    packages = self.forAllSystems { current = self; } (util:
      with util;
        {
          magic = callPackage ./nix/magic.nix {};
          netgen = callPackage ./nix/netgen.nix {};
          ngspice = callPackage ./nix/ngspice.nix {};
          klayout = callPackage ./nix/klayout.nix {};
          klayout-pymod = callPackage ./nix/klayout-pymod.nix {};
          surelog = callPackage ./nix/surelog.nix {};
          tclFull = callPackage ./nix/tclFull.nix {};
          tk-x11 = callPackage ./nix/tk-x11.nix {};
          verilator = callPackage ./nix/verilator.nix {};
          xschem = callPackage ./nix/xschem.nix {};
          yosys-abc = callPackage ./nix/yosys-abc.nix {};
          yosys = callPackage ./nix/yosys.nix {};
          yosys-sby = callPackage ./nix/yosys-sby.nix {};
          yosys-eqy = callPackage ./nix/yosys-eqy.nix {};
          yosys-f4pga-sdc = callPackage ./nix/yosys-f4pga-sdc.nix {};
          yosys-lighter = callPackage ./nix/yosys-lighter.nix {};
          yosys-synlig-sv = callPackage ./nix/yosys-synlig-sv.nix {};
        }
        // (pkgs.lib.optionalAttrs (pkgs.system == "x86_64-linux") {yosys-ghdl = callPackage ./nix/yosys-ghdl.nix {};}));
  };
}
