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
  target,
  lib,
  buildEnv,
  makeBinaryWrapper,
  # extra opts
  extraOutputsToInstall ? [],
  postBuild ? "",
  ignoreCollisions ? false,
  permitUserSite ? false,
  # Wrap executables with the given argument.
  makeWrapperArgs ? [],
}: pkglist: let
  extraLibs = pkglist target.python3.pkgs;
in
  # Create an executable of something that embeds Python with additional packages
  # in its specific Python environment
  let
    env = let
      python3 = target.python3;
      paths = (python3.pkgs.requiredPythonModules (extraLibs ++ [python3])) ++ [target];
      pythonPath = "${placeholder "out"}/${python3.sitePackages}";
      pythonExecutable = "${placeholder "out"}/bin/${python3.executable}";
    in
      buildEnv {
        name = "${target.name}-${python3.name}-env";

        inherit paths;
        inherit ignoreCollisions;
        extraOutputsToInstall = ["out"] ++ extraOutputsToInstall;

        nativeBuildInputs = [makeBinaryWrapper];

        postBuild =
          ''
            rm -rf "$out/bin"
            mkdir -p "$out/bin"

            path=${target}
            if [ -d "$path/bin" ]; then
              cd "$path/bin"
              for prg in *; do
                if [ -f "$prg" ]; then
                  rm -f "$out/bin/$prg"
                  if [ -x "$prg" ]; then
                    makeWrapper "$path/bin/$prg" "$out/bin/$prg"\
                      --set NIX_PYTHONPREFIX "$out"\
                      --set NIX_PYTHONPATH ${pythonPath}\
                      ${lib.optionalString (!permitUserSite) ''--set PYTHONNOUSERSITE "true"''}\
                      ${lib.concatStringsSep " " makeWrapperArgs}
                  fi
                fi
              done
            fi
            ls $out/bin
          ''
          + postBuild;

        inherit (python3) meta;

        passthru =
          python3.passthru
          // {
            interpreter = "${env}/bin/${python3.executable}";
            inherit python3;
            env = target.stdenv.mkDerivation {
              name = "interactive-${target.name}-${python3.name}-environment";
              nativeBuildInputs = [env];

              buildCommand = ''
                echo >&2 ""
                echo >&2 "*** Python 'env' attributes are intended for interactive nix-shell sessions, not for building! ***"
                echo >&2 ""
                exit 1
              '';
            };
          };
      };
  in
    env
