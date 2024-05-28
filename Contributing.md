# Contributing Code
We'd love to accept your patches and contributions to this project. There are just a few small guidelines you need to follow.

## Testing and Code Standards
Please build tools on at least x86_64-linux before submitting them.

The maintainer and/or the CI will attempt to build them for the other three
platforms: x86_64-darwin, aarch64-linux and aarch64-darwin, but if you have
the capacity to test those builds yourselves, it will greatly speed up the PR
process.

Nix code must be formatted using `alejandra`: `nix run nixpkgs#alejandra -- .`

## Submissions
Make your changes and then submit them as a pull requests to the `main` branch.

Consult [GitHub Help](https://help.github.com/articles/about-pull-requests/) for
more information on using pull requests.

## Licensing and Copyright

Please add you (or your employer's) copyright headers to any files to which you
have made major edits.

Please note all code contributions must have the same license as `nix-eda`
proper, i.e., the Apache License, version 2.0. 
