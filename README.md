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
./install_miniforge.bash --python_version 3.14 --miniforge_version 26.7.2-0 --prefix /opt/GEOSpyD
```

will create a Python environment at:
```text
/opt/GEOSpyD/26.7.2-0/YYYY-MM-DD/envs/py3.14
```

The Miniforge base is installed at `/opt/GEOSpyD/26.7.2-0/YYYY-MM-DD`, where
`YYYY-MM-DD` is the date of installation. The date lets installations on
different days coexist; an environment installed again on the same day must
use a different prefix or wait until the next day.

On Linux, ffnet requires `gfortran` 8.3 or newer; by default its absence or
an ffnet build failure stops installation. Use `--ignore-ffnet-errors` to
continue without ffnet. On macOS, a missing compiler skips ffnet automatically.

## Usage

```
Usage: ./install_miniforge.bash --python_version <python version> --miniforge_version <miniforge> --prefix <prefix>
                   [--micromamba | --mamba] [--blas <blas>] [--ffnet-hack] [--ignore-ffnet-errors]

   Required arguments:
      --python_version <python version> (e.g., 3.14)
      --miniforge_version <miniforge_version version> (e.g., 26.7.2-0)
      --prefix <full path to installation directory> (e.g, /opt/GEOSpyD)

   Optional arguments:
      --blas <blas> (default: accelerate, options: mkl, openblas, accelerate, blis)
      --micromamba: Use micromamba installer (default)
      --mamba: Use mamba installer
      --ffnet-hack: Install ffnet from fork (used on Bucy due to odd issue not finding gfortran)
      --ignore-ffnet-errors: Continue if ffnet fails or gfortran is unavailable/too old on Linux (default: fail installation)
      --help: Print this message

   By default we use the micromamba installer on both Linux and macOS
   For BLAS, we use accelerate on Apple Silicon and MKL elsewhere

   NOTE 1: This script installs within /opt/GEOSpyD with a path based on:

        1. The Miniforge version
        2. The date of the installation
   The Python environment is created under envs/py<python version>.

   For example: ./install_miniforge.bash --python_version 3.14 --miniforge_version 26.7.2-0 --prefix /opt/GEOSpyD

   will create an install at:
       /opt/GEOSpyD/26.7.2-0/YYYY-MM-DD/envs/py3.14

  NOTE 2: This script will create or substitute a .mambarc
  and .condarc file in the user's home directory.  If you
  have an existing .mambarc and/or .condarc file, it will be
  restored after installation.  We do this to ensure that the
  installation uses conda-forge as the default channel.
```
