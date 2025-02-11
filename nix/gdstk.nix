{
  lib,
  buildPythonPackage,
  fetchPypi,
  cmake,
  ninja,
  numpy,
  pathspec,
  zlib,
  qhull,
  scikit-build-core,
  pyproject-metadata,
  version ? "0.9.52",
  sha256 ? "sha256-QiZyktJy9KTIIpCR3IOkltChX5ac82aTtVl9P+jvuS8=",
}: let
  self = buildPythonPackage {
    pname = "gdstk";
    format = "pyproject";
    inherit version;

    src = fetchPypi {
      inherit (self) pname version;
      inherit sha256;
    };

    prePatch = ''
      sed -Ei.bak 's/cmake.version = ">=(.+?)"/cmake.minimum-version = "\1"/' pyproject.toml
      sed -i.bak '/oldest-supported-numpy/d' pyproject.toml
    '';

    nativeBuildInputs = [
      scikit-build-core
      cmake
      ninja
      pyproject-metadata
    ];

    dontUseCmakeConfigure = true;

    buildInputs = [
      zlib
      qhull
    ];

    propagatedBuildInputs = [
      numpy
      pathspec
    ];

    meta = {
      description = "Python module for creation and manipulation of GDSII files.";
      homepage = "https://github.com/heitzmann/gdstk";
      license = [lib.licenses.boost];
      platforms = lib.platforms.unix;
    };
  };
in
  self
