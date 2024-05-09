# 🚧 WORK IN PROGRESS 🚧

# ❄️ nix-eda

A [flake](https://nixos.wiki/wiki/Flakes) containing a collection of Nix
derivations for EDA (Electronic Design Automation) utilities, curated by
Efabless Corporation.

We compile and cache the tools for the following platforms:

| Platform | Nix System Name |
| - | - |
| Linux (x86_64) | `x86_64-linux` |
| Linux (aarch64) | `aarch64-linux` |
| macOS (x86_64) | `x86_64-darwin` |
| macOS (arm64) | `aarch64-darwin` |

## Tools Included
* [Magic](http://opencircuitdesign.com/magic)
* [Netgen](http://opencircuitdesign.com/netgen)
* [ngspice](https://ngspice.sourceforge.io)
* [KLayout](https://klayout.de)
    * (+ Python module that can be accessed programmatically)
* [Surelog](https://github.com/chipsalliance/Surelog)
* [Verilator](https://verilator.org)
* [Xschem](https://xschem.sourceforge.io/stefan/index.html)
* [Yosys](https://github.com/YosysHQ/yosys)
    * (+ some plugins that can be accessed programmatically)

## Usage

### Directly

As this repository is a Nix flake, if you have Nix installed with
[flakes enabled](https://nixos.wiki/wiki/Flakes#Other_Distros.2C_without_Home-Manager),
you may use any of the tools by creating a Terminal shell with the tool as follows:

```sh
nix shell github:efabless/nix-eda#magic
```

then simply invoking `magic`.

You may create a shell with multiple tools as follows:

```sh
nix shell github:efabless/nix-eda#{magic,xschem}
```

### As a dependency

To be documented, but you may refer to the
[`nix-eda` branch of OpenLane 2](https://github.com/efabless/openlane2/tree/nix-eda)
as an example of how to use this repository as a dependency. OpenLane 2 uses
this repository in addition to a number of other tools to provide a full
digital design environment.

## ⚖️ License
The Apache License, version 2.0. See 'License'.



