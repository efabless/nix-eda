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
  }: {
    # Common
    input-overlays = [
      (
        new: old: {
          ## Cairo X11 on Mac
          cairo =
            if (old.stdenv.isDarwin)
            then
              (old.cairo.override {
                x11Support = true;
              })
            else (old.cairo);

          ## slightly worse floating point errors cause ONE of the tests to fail on
          ## x86_64-darwin
          qrupdate =
            if old.system == "x86_64-darwin"
            then
              (old.qrupdate.overrideAttrs (finalAttrs: previousAttrs: {
                doCheck = false;
              }))
            else (old.qrupdate);
        }
      )
    ];

    # Helper functions
    createDockerImage = import ./nix/create-docker.nix;

    forAllSystems = {
      current ? null,
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
          lib = nixpkgs.lib;
          inputOverlays = (
            lib.foldl
            (
              acc: elem: let
                packages = elem.packages."${system}";
                pythonPackages = lib.filterAttrs (name: value: builtins.hasAttr "pythonModule" value) elem.packages."${system}";
              in
                acc
                ++ lib.lists.optionals (builtins.hasAttr "input-overlays" elem) elem.input-overlays
                ++ [
                  (new: old: {
                    pythonPackagesExtensions =
                      old.pythonPackagesExtensions
                      ++ [
                        (pnew: pold: pythonPackages)
                      ];
                  })
                  (new: old: packages)
                ]
            )
            []
            withInputs
          );
          pkgs = import nixpkgs {
            inherit system;
            overlays =
              overlays
              ++ inputOverlays
              ++ (
                if current == null
                then []
                else (lib.lists.optionals (builtins.hasAttr "input-overlays" current) current.input-overlays)
              );
          };
          packages-for-arch = function {
            pkgs = pkgs;
            callPackage = pkgs.lib.callPackageWith (pkgs // packages-for-arch);
            callPythonPackage = pkgs.lib.callPackageWith (pkgs // pkgs.python3.pkgs // packages-for-arch);
          };
        in
          packages-for-arch
      );

    # Outputs
    packages =
      self.forAllSystems {
        current = self;
        withInputs = [];
      } (util:
        with util;
          rec {
            magic = callPackage ./nix/magic.nix {};
            magic-vlsi = magic; # alias, there's a python package called magic
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
