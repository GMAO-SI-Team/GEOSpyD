# Repo for managing GEOSpyD installs

## Description

GEOSpyD is the "GEOS Python Distribution". It is a collection of many, many packages that was inherited from SIVOpyD, a set of
scripts for installing Python maintained by @JulesKouatchou.

We do not

## Installation

In order to use the install script, you can run:

```
./install_miniconda.bash --python_version 3.11 --miniconda_version 23.5.2-0 --prefix /opt/GEOSpyD
```

will create an install at:
```
/opt/GEOSpyD/23.5.2-0_py3.11/YYYY-MM-DD
```

where YYYY-MM-DD is the date of the install. We use a date so that if
the stack is re-installed, the previous install is not overwritten.

## Usage

```
Usage: ./install_miniconda.bash --python_version <python version> --miniconda_version <miniconda_version> --prefix <prefix> [--conda]

   Required arguments:
      --python_version <python version> (e.g., 3.11)
      --miniconda_version <miniconda_version version> (e.g., 25.3.2-0)
      --prefix <full path to installation directory> (e.g, /opt/GEOSpyD)

   Optional arguments:
      --blas <blas> (default: accelerate, options: mkl, openblas, accelerate)
      --conda: Use conda installer (NOT recommended, only for legacy support)
      --mamba: Use mamba installer (default on Linux)
      --micromamba: Use micromamba installer (default on macOS)
      --help: Print this message

   By default we use the micromamba installer on macOS and mamba on Linux

   NOTE 1: This script installs within /opt/GEOSpyD with a path based on:

        1. The Miniconda version
        2. The Python version
        3. The date of the installation

   For example: ./install_miniconda.bash --python_version 3.11 --miniconda_version 25.3.2-0 --prefix /opt/GEOSpyD

   will create an install at:
       /opt/GEOSpyD/25.3.2-0_py3.11/2023-10-17

  NOTE 2: This script will create or substitute a .condarc file in the user's home directory.
          If you have an existing .condarc file, it will be restored after installation.
          We do this to ensure that the installation uses conda-forge as the default channel.
```
