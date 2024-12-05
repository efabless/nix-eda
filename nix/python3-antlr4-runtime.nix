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
  buildPythonPackage,
  antlr4,
}:
buildPythonPackage {
  pname = "${antlr4.pname}-python3-runtime";
  inherit (antlr4.runtime.cpp) version src meta;
  
  doCheck = false; # "mocks" not packaged for NixOS

  sourceRoot = "source/runtime/Python3";
}
