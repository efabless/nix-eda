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
  lib,
  fetchFromGitHub,
  buildPythonPackage,
  ply,
  schema,
  pathspec,
  importlib-metadata,
  pygls,
  setuptools,
  setuptools_scm,
  version ? "0.5.0",
  sha256 ? "sha256-FT0a0pYhpsr0xlehrg+QqyPqOaM0paU+iG0+Bx8tDrU=",
}: let
  self = buildPythonPackage {
    pname = "tclint";
    inherit version;
    format = "pyproject";

    src = fetchFromGitHub {
      owner = "nmoroze";
      repo = self.pname;
      rev = "v${self.version}";
      inherit sha256;
    };
    
    patchPhase = ''
      runHook prePatch
      sed -Ei 's/schema==[0-9.]+/schema==${schema.version}/' pyproject.toml
      sed -Ei 's/pathspec==[0-9.]+/pathspec==${pathspec.version}/' pyproject.toml
      sed -Ei 's/importlib-metadata==[0-9.]+/importlib-metadata==${importlib-metadata.version}/' pyproject.toml
      runHook postPatch
    '';
    
    nativeBuildInputs = [
      setuptools
      setuptools_scm
    ];
    
    buildInputs = [
      ply
      schema
      pathspec
      importlib-metadata
      pygls
    ];
  };
in
  self
