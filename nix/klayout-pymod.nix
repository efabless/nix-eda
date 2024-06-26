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
  clangStdenv,
  klayout,
  python3,
}:
python3.pkgs.toPythonModule (clangStdenv.mkDerivation rec {
  name = "klayout-pymod";
  buildInputs = [klayout];
  unpackPhase = "true";
  installPhase = ''
    mkdir -p $out/${python3.sitePackages}
    ln -s ${klayout}/lib/pymod/klayout $out/${python3.sitePackages}/klayout
    ln -s ${klayout}/lib/pymod/pya $out/${python3.sitePackages}/pya
    ln -s ${klayout}/lib/pymod/klayout*.dist-info $out/${python3.sitePackages}/
  '';
  meta = with lib; {
    description = "Python API access to KLayout";
    license = with licenses; [gpl3Plus];
    homepage = "https://www.klayout.de/";
    platforms = platforms.all;
  };
})
