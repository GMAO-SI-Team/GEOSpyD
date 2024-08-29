# Repo for managing GEOSpyD installs

## Description

GEOSpyD is the "GEOS Python Distribution". It is a collection of many, many packages that was inherited from SIVOpyD, a set of
scripts for installing Python maintained by @JulesKouatchou.

This script now uses Miniforge and restricts the installation to use `conda-forge` and `nodefaults` as the channels. Moreover,
to prevent infection from the Anaconda `defaults` channel, the script at the end checks the output of `mamba list` to make sure no
`defaults` packages appear. If they do, the script will exit with an error message.

## Installation

In order to use the install script, you can run:

```
./install_miniforge.bash --python_version 3.12 --miniforge_version 24.5.0-0 --prefix /opt/GEOSpyD
```

will create an install at:
```
/opt/GEOSpyD/24.5.0-0_py3.12/YYYY-MM-DD
```

where YYYY-MM-DD is the date of the install. We use a date so that if
the stack is re-installed, the previous install is not overwritten.

## Usage

```
Usage: ./install_miniforge.bash --python_version <python version> --miniforge_version <miniforge> --prefix <prefix> [--micromamba | --mamba] [--blas <blas>]

   Required arguments:
      --python_version <python version> (e.g., 3.12)
      --miniforge_version <miniforge_version version> (e.g., 24.5.0-0)
      --prefix <full path to installation directory> (e.g, /opt/GEOSpyD)

   Optional arguments:
      --blas <blas> (default: accelerate, options: mkl, openblas, accelerate, blis)
      --micromamba: Use micromamba installer (default)
      --mamba: Use mamba installer
      --help: Print this message

   By default we use the micromamba installer on both Linux and macOS
   For BLAS, we use accelerate on macOS and MKL on Linux

   NOTE 1: This script installs within /opt/GEOSpyD with a path based on:

        1. The Miniforge version
        2. The Python version
        3. The date of the installation

   For example: ./install_miniforge.bash --python_version 3.12 --miniforge_version 24.5.0-0 --prefix /opt/GEOSpyD

   will create an install at:
       /opt/GEOSpyD/24.5.0-0_py3.12/2024-08-29

  NOTE 2: This script will create or substitute a .mambarc
  and .condarc file in the user's home directory.  If you
  have an existing .mambarc and/or .condarc file, it will be
  restored after installation.  We do this to ensure that the
  installation uses conda-forge as the default channel.
```
