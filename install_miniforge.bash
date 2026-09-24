#!/bin/bash

set -Eeuo pipefail

# Restore the user's configuration even when installation fails.
cleanup() {
   local ret=$?
   trap - EXIT INT TERM
   if [[ $MAMBARC_FOUND == TRUE ]]
   then
      cp -v "$ORIG_MAMBARC" ~/.mambarc || ret=1
   elif [[ $CONFIG_WRITTEN == TRUE ]]
   then
      rm -f ~/.mambarc || ret=1
   fi
   if [[ $CONDARC_FOUND == TRUE ]]
   then
      cp -v "$ORIG_CONDARC" ~/.condarc || ret=1
   elif [[ $CONFIG_WRITTEN == TRUE ]]
   then
      rm -f ~/.condarc || ret=1
   fi
   if [[ -n $ORIG_MAMBARC ]]
   then
      rm -f "$ORIG_MAMBARC" || ret=1
   fi
   if [[ -n $ORIG_CONDARC ]]
   then
      rm -f "$ORIG_CONDARC" || ret=1
   fi
   exit "$ret"
}

MAMBARC_FOUND=FALSE
CONDARC_FOUND=FALSE
CONFIG_WRITTEN=FALSE
ORIG_MAMBARC=''
ORIG_CONDARC=''
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# -----------------
# Detect usual bits
# -----------------

ARCH=$(uname -s)
MACH=$(uname -m)

# -----------------------------------
# Set the Default BLAS implementation
# -----------------------------------

if [[ $ARCH == Darwin ]]
then
   if [[ $MACH == arm64 ]]
   then
      BLAS_IMPL=accelerate
      # Note: accelerate might have issues with scipy
      #       See https://github.com/conda-forge/numpy-feedstock/issues/253
   else
      BLAS_IMPL=mkl
   fi
else
   BLAS_IMPL=mkl
fi
# -----
# Usage
# -----

EXAMPLE_PY_VERSION="3.14"
EXAMPLE_MINI_VERSION="26.7.2-0"
EXAMPLE_INSTALLDIR="/opt/GEOSpyD"
EXAMPLE_DATE=$(date +%F)
usage() {
   echo "Usage: $0 --python_version <python version> --miniforge_version <miniforge> --prefix <prefix>"
   echo "                   [--micromamba | --mamba] [--blas <blas>] [--ffnet-hack] [--ignore-ffnet-errors]"
   echo ""
   echo "   Required arguments:"
   echo "      --python_version <python version> (e.g., ${EXAMPLE_PY_VERSION})"
   echo "      --miniforge_version <miniforge_version version> (e.g., ${EXAMPLE_MINI_VERSION})"
   echo "      --prefix <full path to installation directory> (e.g, ${EXAMPLE_INSTALLDIR})"
   echo ""
   echo "   Optional arguments:"
   echo "      --blas <blas> (default: ${BLAS_IMPL}, options: mkl, openblas, accelerate, blis)"
   echo "      --micromamba: Use micromamba installer (default)"
   echo "      --mamba: Use mamba installer"
   echo "      --ffnet-hack: Install ffnet from fork (used on Bucy due to odd issue not finding gfortran)"
   echo "      --ignore-ffnet-errors: Continue if ffnet fails or gfortran is unavailable/too old on Linux (default: fail installation)"
   echo "      --help: Print this message"
   echo ""
   echo "   By default we use the micromamba installer on both Linux and macOS"
   echo "   For BLAS, we use accelerate on Apple Silicon and MKL elsewhere"
   echo ""
   echo "   NOTE 1: This script installs within ${EXAMPLE_INSTALLDIR} with a path based on:"
   echo ""
   echo "        1. The Miniforge version"
   echo "        2. The date of the installation"
   echo "   The Python environment is created under envs/py<python version>."
   echo ""
   echo "   For example: $0 --python_version ${EXAMPLE_PY_VERSION} --miniforge_version ${EXAMPLE_MINI_VERSION} --prefix ${EXAMPLE_INSTALLDIR}"
   echo ""
   echo "   will create an install at:"
   echo "       ${EXAMPLE_INSTALLDIR}/${EXAMPLE_MINI_VERSION}/${EXAMPLE_DATE}/envs/py${EXAMPLE_PY_VERSION}"
   echo ""
   echo "  NOTE 2: This script will create or substitute a .mambarc    "
   echo "  and .condarc file in the user's home directory.  If you     "
   echo "  have an existing .mambarc and/or .condarc file, it will be  "
   echo "  restored after installation.  We do this to ensure that the "
   echo "  installation uses conda-forge as the default channel.       "
}

# From http://stackoverflow.com/a/246128/1876449
# ----------------------------------------------
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPTDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# ------------------------------
# Define an in-place sed command
# Because Mac sed is stupid old,
# use gsed if found.
# ------------------------------

if [[ $ARCH == Darwin ]]
then
   if [[ $(command -v gsed) ]]
   then
      #echo "Found gsed on macOS. Good job! You are smart!"
      SED_INPLACE=("$(command -v gsed)" -i)
   else
      #echo "It is recommended to use GNU sed since macOS default"
      #echo "sed is a useless BSD variant. Consider installing"
      #echo "GNU sed from a packager like Homebrew:"
      #echo "  brew install gnu-sed"
      SED_INPLACE=("$(command -v sed)" -i.macbak)
   fi
else
   SED_INPLACE=("$(command -v sed)" -i)
fi

# ----------------------
# Command line arguments
# ----------------------

USE_MAMBA=FALSE
USE_MICROMAMBA=TRUE
FFNET_HACK=FALSE
IGNORE_FFNET_ERRORS=FALSE
PYTHON_VER=''
MINIFORGE_VER=''
MINIFORGE_DIR=''

while [[ $# -gt 0 ]]
do
   case "$1" in
      --python_version|--miniforge_version|--prefix|--blas)
         if [[ $# -lt 2 || $2 == --* ]]
         then
            echo "ERROR: $1 requires a value"
            usage
            exit 1
         fi
         ;;
   esac
   case "$1" in
      --python_version)
         PYTHON_VER=$2
         shift
         ;;
      --miniforge_version)
         MINIFORGE_VER=$2
         shift
         ;;
      --mamba)
         USE_MAMBA=TRUE
         USE_MICROMAMBA=FALSE
         ;;
      --micromamba)
         USE_MAMBA=FALSE
         USE_MICROMAMBA=TRUE
         ;;
      --ffnet-hack)
         FFNET_HACK=TRUE
         ;;
      --ignore-ffnet-errors)
         IGNORE_FFNET_ERRORS=TRUE
         ;;
      --prefix)
         MINIFORGE_DIR=$2
         shift
         ;;
      --blas)
         BLAS_IMPL=$2
         shift
         ;;
      --help | -h)
         usage
         exit 0
         ;;
      *)
         echo "Option $1 not recognized"
         usage
         exit 1
         ;;
   esac
   shift
done

if [[ -z $PYTHON_VER ]]
then
   echo "ERROR: Python version not sent in"
   usage
   exit 1
fi

if [[ -z $MINIFORGE_VER ]]
then
   echo "ERROR: Miniforge version not sent in"
   usage
   exit 1
fi

if [[ -z $MINIFORGE_DIR ]]
then
   echo "ERROR: Miniforge installation directory not sent in"
   usage
   exit 1
fi

# We will only allow BLAS_IMPL to be: mkl, openblas, accelerate, or blis
if [[ $BLAS_IMPL != mkl && $BLAS_IMPL != openblas && $BLAS_IMPL != accelerate && $BLAS_IMPL != blis ]]
then
   echo "ERROR: BLAS implementation $BLAS_IMPL not recognized"
   usage
   exit 1
fi


# To install ffnet we require a Fortran
# compiler and for portability's sake we require gfortran. Moreover, we
# require that gfortran be at least version 8.3.0.
#
# We'll do the test now as to not waste time if the user has a
# too-old gfortran.
#
# We have two situations. On Linux we *require* gfortran to be
# installed. We assume that it's called gfortran as it is on most Linux
# distros. On macOS, we check for gfortran, gfortran-11, -12, or -13 (as
# those are available via brew).

# First look if gfortran is available
# -----------------------------------

FORTRAN_AVAILABLE=FALSE
GFORTRAN=''

if [[ $ARCH == Darwin ]]
then
   if command -v gfortran >/dev/null 2>&1
   then
      GFORTRAN=gfortran
   elif command -v gfortran-11 >/dev/null 2>&1
   then
      GFORTRAN=gfortran-11
   elif command -v gfortran-12 >/dev/null 2>&1
   then
      GFORTRAN=gfortran-12
   elif command -v gfortran-13 >/dev/null 2>&1
   then
      GFORTRAN=gfortran-13
   else
      echo "WARNING: gfortran is not available. If you wish to install ffnet, please install it or load an appropriate module."
      echo "         For now we will skip the installation of ffnet"
   fi
   if [[ -n $GFORTRAN ]]
   then
      echo "Found $GFORTRAN on macOS. Will be used for ffnet"
      FORTRAN_AVAILABLE=TRUE
   fi
else
   if command -v gfortran >/dev/null 2>&1
   then
      GFORTRAN=gfortran
      echo "Found gfortran on Linux. Will be used for ffnet"
      FORTRAN_AVAILABLE=TRUE
   else
      if [[ $IGNORE_FFNET_ERRORS == TRUE ]]
      then
         echo "WARNING: gfortran is not available; skipping ffnet because --ignore-ffnet-errors was specified."
      else
         echo "ERROR: gfortran is not available. Please install it or load an appropriate module."
         echo "       We require at least version 8.3.0 to install ffnet"
         exit 9
      fi
   fi
fi

# Now check the version
# ---------------------

if [[ $FORTRAN_AVAILABLE == TRUE ]]
then

   # First get the version string as the last field of the first
   # line of the output of gfortran --version
   GFORTRAN_VERSION=$("$GFORTRAN" --version | head -n 1 | awk '{print $NF}')

   # Now split the version string into its major and minor components
   GFORTRAN_MAJOR=$(echo "$GFORTRAN_VERSION" | awk -F. '{print $1}')
   GFORTRAN_MINOR=$(echo "$GFORTRAN_VERSION" | awk -F. '{print $2}')

   # Now, we want to know if gfortran is 8.3 or higher.

   # Check if gfortran is older than 8.3.0
   if [[ $GFORTRAN_MAJOR -lt 8 || ( $GFORTRAN_MAJOR -eq 8 && $GFORTRAN_MINOR -lt 3 ) ]]
   then
      if [[ $IGNORE_FFNET_ERRORS == TRUE ]]
      then
         echo "WARNING: gfortran is too old; skipping ffnet because --ignore-ffnet-errors was specified."
         FORTRAN_AVAILABLE=FALSE
      else
         echo "ERROR: gfortran is too old. Please install at least version 8.3.0 or load an appropriate module."
         exit 9
      fi
   fi

   # If the compiler is too old, ffnet is skipped when requested above.
fi

# ---------------------------
# Miniforge version variables
# ---------------------------

PYTHON_MAJOR_VERSION=${PYTHON_VER:0:1}
if [[ "$PYTHON_MAJOR_VERSION" != "3" ]]
then
   echo "Python version $PYTHON_VER implies Python major version $PYTHON_MAJOR_VERSION"
   echo "This script only supports Python 3"
   exit 2
fi
PYTHON_EXEC=python${PYTHON_MAJOR_VERSION}
PYTHON_VER_WITHOUT_DOT="${PYTHON_VER//./}"

MINIFORGE_DISTVER=Miniforge${PYTHON_MAJOR_VERSION}

MINIFORGE_SRCDIR=${SCRIPTDIR}/$MINIFORGE_DISTVER

# ------------------------------
# Set the Miniforge Architecture
# ------------------------------

if [[ $ARCH == Darwin ]]
then
   MINIFORGE_ARCH=MacOSX
   if [[ $MACH == arm64 ]]
   then
      MICROMAMBA_ARCH=osx-arm64
      # Note: accelerate might have issues with scipy
      #       See https://github.com/conda-forge/numpy-feedstock/issues/253
   else
      MICROMAMBA_ARCH=osx-64
   fi
else
   MINIFORGE_ARCH=Linux
   MICROMAMBA_ARCH=linux-64
fi

# -----------------------------------------------------
# Create the installtion directory if it does not exist
# -----------------------------------------------------

if [ ! -d "$MINIFORGE_DIR" ]
then
   mkdir -p "$MINIFORGE_DIR"
fi

DATE=$(date +%F)
MINIFORGE_INSTALLDIR=$MINIFORGE_DIR/${MINIFORGE_VER}/$DATE
MINIFORGE_ENVNAME=py${PYTHON_VER}
MINIFORGE_ENVDIR=$MINIFORGE_INSTALLDIR/envs/${MINIFORGE_ENVNAME}

CANONICAL_INSTALLER=${MINIFORGE_DISTVER}-${MINIFORGE_VER}-${MINIFORGE_ARCH}-${MACH}.sh
if [[ "$MINIFORGE_VER" == "latest" ]]
then
   DATED_INSTALLER=${MINIFORGE_DISTVER}-${MINIFORGE_VER}-${MINIFORGE_ARCH}-${MACH}.${DATE}.sh
fi

echo "MINIFORGE_SRCDIR     = $MINIFORGE_SRCDIR"
echo "CANONICAL_INSTALLER  = $MINIFORGE_SRCDIR/$CANONICAL_INSTALLER"
if [[ "$MINIFORGE_VER" == "latest" ]]
then
   echo "DATED_INSTALLER      = $MINIFORGE_SRCDIR/$DATED_INSTALLER"
fi
echo "Miniforge $MINIFORGE_VER for Python $PYTHON_VER will be installed in $MINIFORGE_ENVDIR"

if [[ -d $MINIFORGE_ENVDIR ]]
then
   echo "ERROR: $MINIFORGE_ENVDIR already exists! Exiting!"
   exit 9
fi

if [[ ! -f $MINIFORGE_SRCDIR/$CANONICAL_INSTALLER ]]
then
   REPO=https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VER}
   echo "Downloading $CANONICAL_INSTALLER from $REPO"
   echo "Running curl -OL $REPO/$CANONICAL_INSTALLER"
   (cd "$MINIFORGE_SRCDIR"; curl -OL "$REPO/$CANONICAL_INSTALLER")
fi

if [[ "$MINIFORGE_VER" == "latest" ]]
then
   mv -v "$MINIFORGE_SRCDIR/$CANONICAL_INSTALLER" "$MINIFORGE_SRCDIR/$DATED_INSTALLER"
   INSTALLER=$DATED_INSTALLER
else
   INSTALLER=$CANONICAL_INSTALLER
fi

# NOTE: We have to use strict conda-forge channel
# -----------------------------------------------

# Back up user configuration only when we are about to change it.
ORIG_MAMBARC=$(mktemp)
if [[ -f ~/.mambarc ]]
then
   cp -v ~/.mambarc "$ORIG_MAMBARC"
   MAMBARC_FOUND=TRUE
fi

ORIG_CONDARC=$(mktemp)
if [[ -f ~/.condarc ]]
then
   cp -v ~/.condarc "$ORIG_CONDARC"
   CONDARC_FOUND=TRUE
fi

# Now create the good one (we restore the old one at the end)
CONFIG_WRITTEN=TRUE
cat << EOF > ~/.mambarc
# Temporary mambarc from install_miniforge.bash
channels:
  - conda-forge
  - nodefaults
channel_priority: strict
use_lockfiles: False
EOF

cat << EOF > ~/.condarc
# Temporary condarc from install_miniforge.bash
channels:
  - conda-forge
  - nodefaults
channel_priority: strict
use_lockfiles: False
EOF

# ----------------------
# Install Miniforge Base
# ----------------------

if [[ ! -d $MINIFORGE_INSTALLDIR ]]
then
   bash "$MINIFORGE_SRCDIR/$INSTALLER" -b -p "$MINIFORGE_INSTALLDIR"
fi

export MAMBA_ROOT_PREFIX=$MINIFORGE_INSTALLDIR

MINIFORGE_BINDIR=$MINIFORGE_INSTALLDIR/bin

# --------------------------------
# Create the Miniforge environment
# --------------------------------

"$MINIFORGE_BINDIR/mamba" create -y -p "$MINIFORGE_ENVDIR" "python=$PYTHON_VER"

# Now install regular mamba packages
# ----------------------------------

function mamba_install {
   echo
   echo "(mamba) Now installing $*"
   "$MINIFORGE_BINDIR/mamba" install -p "$MINIFORGE_ENVDIR" -y "$@"
   echo
}

function micromamba_install {
   echo
   echo "(micromamba) Now installing $*"
   "$MINIFORGE_BINDIR/micromamba" install -p "$MINIFORGE_ENVDIR" -y "$@"
   echo
}

if [[ "$USE_MICROMAMBA" == "TRUE" ]]
then
   echo "=== Using micromamba as package manager ==="

   PACKAGE_INSTALL=micromamba_install

   # We also need to fetch micromamba
   # --------------------------------

   echo "=== Installing micromamba ==="
   MICROMAMBA_URL="https://micro.mamba.pm/api/micromamba/${MICROMAMBA_ARCH}/latest"
   curl -Ls "$MICROMAMBA_URL" | tar -C "$MINIFORGE_INSTALLDIR" -xvj bin/micromamba

elif [[ "$USE_MAMBA" == "TRUE" ]]
then
   echo "=== Using mamba as package manager ==="
   PACKAGE_INSTALL=mamba_install

else
   echo "ERROR: No package manager selected! We should not get here. Exiting!"
   exit 9
fi

# --------------
# MAMBA PACKAGES
# --------------

$PACKAGE_INSTALL mamba

echo "BLAS_IMPL: $BLAS_IMPL"
$PACKAGE_INSTALL "libblas=*=*${BLAS_IMPL}"

# in libcxx 14.0.6 (from miniforge), __string is a file, but in 16.0.6
# it is a directory so, in order for libcxx to be updated, we have to
# remove it because the updater will fail
#
# This seems to only happen on macOS

if [[ $ARCH == Darwin ]]
then
   # First let's check the version of libcxx installed by asking mamba

   LIBCXX_VERSION=$("$MINIFORGE_ENVDIR/bin/mamba" list libcxx | grep libcxx | awk '{print $2}')

   # This is the version X.Y.Z and we want to do things only if X is 14 as it's a directory in 15+
   # Let's use bash to extract the first number
   LIBCXX_MAJOR_VERSION=${LIBCXX_VERSION%%.*}
   MINIFORGE_MAJOR_VERSION=${MINIFORGE_VER%%.*}

   if [[ $LIBCXX_MAJOR_VERSION -lt 15 && $MINIFORGE_MAJOR_VERSION -ge 23 ]]
   then
      if [[ -f $MINIFORGE_ENVDIR/include/c++/v1/__string ]]
      then
         echo "Removing $MINIFORGE_ENVDIR/include/c++/v1/__string"
         rm "$MINIFORGE_ENVDIR/include/c++/v1/__string"
      fi
      if [[ -f $MINIFORGE_ENVDIR/include/c++/v1/__tuple ]]
      then
         echo "Removing $MINIFORGE_ENVDIR/include/c++/v1/__tuple"
         rm "$MINIFORGE_ENVDIR/include/c++/v1/__tuple"
      fi
   fi
fi

$PACKAGE_INSTALL esmpy
$PACKAGE_INSTALL xesmf
$PACKAGE_INSTALL pytest
$PACKAGE_INSTALL xgcm
$PACKAGE_INSTALL s3fs boto3
$PACKAGE_INSTALL pip pipenv

$PACKAGE_INSTALL numpy scipy
$PACKAGE_INSTALL numba
$PACKAGE_INSTALL netcdf4 cartopy proj matplotlib h5netcdf
$PACKAGE_INSTALL virtualenv configargparse
$PACKAGE_INSTALL psycopg2 gdal xarray geotiff plotly
$PACKAGE_INSTALL iris pyhdf biggus hpccm cdsapi
$PACKAGE_INSTALL babel beautifulsoup4 colorama gmp jupyter jupyterlab
$PACKAGE_INSTALL movingpandas geoviews hvplot">=0.11.0" geopandas bokeh jupyter_bokeh
$PACKAGE_INSTALL skimpy
$PACKAGE_INSTALL intake intake-parquet intake-xarray

# Looks like mo_pack and libmo_unpack are not available on arm64
if [[ $MACH == arm64 ]]
then
   $PACKAGE_INSTALL pygrib f90nml seawater
   $PACKAGE_INSTALL cmocean eofs
else
   $PACKAGE_INSTALL pygrib f90nml seawater mo_pack libmo_unpack
   $PACKAGE_INSTALL cmocean eofs
   $PACKAGE_INSTALL pyspharm windspharm
fi

$PACKAGE_INSTALL pyasn1 ujson configobj argcomplete biopython
# mdp only exists from 3.10 and older
if [[ $PYTHON_VER_WITHOUT_DOT -le 310 ]]
then
   $PACKAGE_INSTALL mdp
fi
$PACKAGE_INSTALL requests-toolbelt twine wxpython
$PACKAGE_INSTALL sockjs-tornado sphinx_rtd_theme django
$PACKAGE_INSTALL pypng seaborn astropy
$PACKAGE_INSTALL fastcache greenlet imageio jbig lzo
$PACKAGE_INSTALL mock pytables
$PACKAGE_INSTALL pydap
$PACKAGE_INSTALL gsw

$PACKAGE_INSTALL timezonefinder
$PACKAGE_INSTALL cython
$PACKAGE_INSTALL zarr

$PACKAGE_INSTALL scikit-learn

$PACKAGE_INSTALL yamllint
$PACKAGE_INSTALL verboselogs

$PACKAGE_INSTALL pykdtree pyogrio contourpy sunpy
$PACKAGE_INSTALL haversine
$PACKAGE_INSTALL ford
$PACKAGE_INSTALL autopep8
$PACKAGE_INSTALL mdutils
$PACKAGE_INSTALL earthaccess

$PACKAGE_INSTALL uxarray

$PACKAGE_INSTALL rasterio contextily

$PACKAGE_INSTALL basemap

$PACKAGE_INSTALL libmagic python-magic

# Only install pythran on linux. On mac it brings in an old clang
if [[ $MINIFORGE_ARCH == Linux ]]
then
   $PACKAGE_INSTALL f90wrap
   $PACKAGE_INSTALL pythran
fi

# esmpy installs mpi. We don't want any of those in the bin dir
# so we rename and relink. First we rename the files:

cd "$MINIFORGE_ENVDIR/bin"

/bin/mv -v mpicc         esmf-mpicc
/bin/mv -v mpicxx        esmf-mpicxx
/bin/mv -v mpiexec.hydra esmf-mpiexec.hydra
/bin/mv -v mpifort       esmf-mpifort
/bin/mv -v mpichversion  esmf-mpichversion
/bin/mv -v mpivars       esmf-mpivars

# Now we have to handle the symlinks
/bin/rm -v mpic++  && /bin/ln -sv esmf-mpicxx        esmf-mpic++
/bin/rm -v mpiexec && /bin/ln -sv esmf-mpiexec.hydra esmf-mpiexec
/bin/rm -v mpirun  && /bin/ln -sv esmf-mpiexec.hydra esmf-mpirun
/bin/rm -v mpif77  && /bin/ln -sv esmf-mpifort       esmf-mpif77
/bin/rm -v mpif90  && /bin/ln -sv esmf-mpifort       esmf-mpif90

# We also want to link f2py to f2py3 for Python 3
/bin/ln -sv f2py f2py3

cd "$SCRIPTDIR"

# Install weird nc_time_axis package
# ----------------------------------
$PACKAGE_INSTALL -c conda-forge/label/renamed nc_time_axis

# ------------
# PIP PACKAGES
# ------------

PIP_INSTALL=("$MINIFORGE_ENVDIR/bin/$PYTHON_EXEC" -m pip install)
PIP_UNINSTALL=("$MINIFORGE_ENVDIR/bin/$PYTHON_EXEC" -m pip uninstall -y)

"${PIP_INSTALL[@]}" PyRTF3 pipenv pymp-pypi h5py
"${PIP_INSTALL[@]}" pycircleci metpy siphon questionary xgrads
"${PIP_INSTALL[@]}" ruamel.yaml
"${PIP_INSTALL[@]}" xgboost

# Tensorflow does not support Python 3.14 yet
# https://github.com/tensorflow/tensorflow/issues/102890
if [[ $PYTHON_VER_WITHOUT_DOT -ge 314 ]]
then
   echo "Skipping tensorflow installation as Python $PYTHON_VER is 3.14 or higher"
else
   "${PIP_INSTALL[@]}" tensorflow evidential-deep-learning silence_tensorflow
fi
"${PIP_INSTALL[@]}" torch torchvision
"${PIP_INSTALL[@]}" yaplon
"${PIP_INSTALL[@]}" lxml
"${PIP_INSTALL[@]}" juliandate
"${PIP_INSTALL[@]}" pybufrkit
"${PIP_INSTALL[@]}" pyephem
"${PIP_INSTALL[@]}" redis
"${PIP_INSTALL[@]}" Flask
"${PIP_INSTALL[@]}" goes2go
"${PIP_INSTALL[@]}" nco
"${PIP_INSTALL[@]}" cdo
"${PIP_INSTALL[@]}" ecmwf-opendata
"${PIP_INSTALL[@]}" python-docx
"${PIP_INSTALL[@]}" openpyxl
"${PIP_INSTALL[@]}" adjustText

# some packages require a Fortran compiler. This sometimes isn't available
# on macs (though usually is)
if [[ $FORTRAN_AVAILABLE == TRUE ]]
then
   echo "We have a Fortran compiler. Installing ffnet (Python $PYTHON_VER)"
   # we need to install ffnet from https://github.com/mrkwjc/ffnet.git
   # This is because the version in PyPI is not compatible with Python 3
   # and latest scipy
   #
   # 1. This package now requires meson to build (for Python 3.12)
   "${PIP_INSTALL[@]}" meson
   # 1b. If we are running Python 3.13 or higher, we need to explicitly
   #     install setuptools and wheel as they are not installed by default
   if [[ $PYTHON_VER_WITHOUT_DOT -ge 313 ]]
   then
      "${PIP_INSTALL[@]}" setuptools wheel
   fi
    # For Python 3.13+, pip's isolated build environment does not inherit the
   # conda env packages (e.g. numpy), which ffnet needs at build time. Passing
   # --no-build-isolation tells pip to use the already-installed packages from
   # the conda env instead of creating a fresh isolated sandbox.
   # 2. We also need f2py but that is in our install directory bin
   #    so we need to add that to the PATH
   export PATH=$MINIFORGE_ENVDIR/bin:$PATH
   # 3. We also should redefine TMPDIR as on some systems (discover)
   #    it seems to not work as hoped. So, we create a new directory
   #    relative to the install script called tmp, and use that.
   #    It appears meson uses TMPDIR to store its build files.
   mkdir -p "$SCRIPTDIR/tmp-for-ffnet"
   export TMPDIR="$SCRIPTDIR/tmp-for-ffnet"
   # 4. Now we can install ffnet
   if [[ $FFNET_HACK == TRUE ]]
   then
      FFNET_SOURCE=git+https://github.com/mathomp4/ffnet@force-env-gfortran
   else
      FFNET_SOURCE=git+https://github.com/mrkwjc/ffnet
   fi
   if [[ $PYTHON_VER_WITHOUT_DOT -ge 313 ]]
   then
      FFNET_PIP_STATUS=0
      FC="$GFORTRAN" F77="$GFORTRAN" "${PIP_INSTALL[@]}" --no-build-isolation "$FFNET_SOURCE" || FFNET_PIP_STATUS=$?
   else
      FFNET_PIP_STATUS=0
      FC="$GFORTRAN" F77="$GFORTRAN" "${PIP_INSTALL[@]}" "$FFNET_SOURCE" || FFNET_PIP_STATUS=$?
   fi
   if [[ $FFNET_PIP_STATUS -ne 0 ]]
   then
      if [[ $IGNORE_FFNET_ERRORS == TRUE ]]
      then
         echo "WARNING: ffnet installation failed; continuing because --ignore-ffnet-errors was specified."
      else
         echo "ERROR: ffnet installation failed. Use --ignore-ffnet-errors to continue without ffnet."
         rm -rf "$SCRIPTDIR/tmp-for-ffnet"
         exit 1
      fi
   fi
   # 5. We can now remove the tmp directory
   rm -rf "$SCRIPTDIR/tmp-for-ffnet"
fi

# Finally pygrads is not in pip
# -----------------------------

PYGRADS_VERSION="pygrads-3.0.b1"
if [[ -d $MINIFORGE_SRCDIR/$PYGRADS_VERSION ]]
then
   rm -rf "${MINIFORGE_SRCDIR:?}/$PYGRADS_VERSION"
fi

tar xf "$MINIFORGE_SRCDIR/$PYGRADS_VERSION.tar.gz" -C "$MINIFORGE_SRCDIR"

cd "$MINIFORGE_SRCDIR/$PYGRADS_VERSION"

"$MINIFORGE_ENVDIR/bin/$PYTHON_EXEC" setup.py install

# Inject code fix for spectral
# ----------------------------
# SED_INPLACE contains the appropriate in-place option for the platform.
find "$MINIFORGE_ENVDIR/lib" -name 'gacm.py' -print0 | xargs -0 "${SED_INPLACE[@]}" -e '/cm.spectral,/ s/spectral/nipy_spectral/'

cd "$SCRIPTDIR"

# Edit matplotlibrc to use TkAgg as the default backend for matplotlib
# on Linux, but MacOSX on macOS
# --------------------------------------------------------------------
#
# What we need to do is look for the string "backend:" in matplotlibrc
# and change line (which might have one or more comment characters at
# the beginning) to be "backend: MacOSX" on macOS and "backend: TkAgg"
# on Linux.
#
if [[ $ARCH == Darwin ]]
then
   find "$MINIFORGE_ENVDIR/lib" -name 'matplotlibrc' -print0 | xargs -0 "${SED_INPLACE[@]}" -e '/.*backend:/ s/^.*backend:.*/backend: MacOSX/'
else
   find "$MINIFORGE_ENVDIR/lib" -name 'matplotlibrc' -print0 | xargs -0 "${SED_INPLACE[@]}" -e '/.*backend:/ s/^.*backend:.*/backend: TkAgg/'
fi

# There currently seems to be a bug with ipython3
# (see https://github.com/ipython/ipython/issues/14260)
# the solution seems to be to pip uninstall prompt_toolkit
# and then reinstall it. This is a temporary fix until
# the issue is resolved.
"${PIP_UNINSTALL[@]}" prompt_toolkit
"${PIP_INSTALL[@]}" prompt_toolkit

# Use mamba to output list of packages installed
# ----------------------------------------------
cd "$MINIFORGE_ENVDIR"
"$MINIFORGE_BINDIR"/mamba list -p "$MINIFORGE_ENVDIR" --explicit > distribution_spec_file.txt
"$MINIFORGE_BINDIR"/mamba list -p "$MINIFORGE_ENVDIR" > mamba_list_packages.txt
./bin/pip freeze > pip_freeze_packages.txt

# As a final check to make sure the defaults channel has not
# infected the environment, we will check the mamba_list_packages.txt
# and make sure 'defaults' does not appear in the channel list (fourth
# field)
# -------------------------------------------------------------------

if grep -q defaults mamba_list_packages.txt
then
   echo "ERROR: The defaults channel is in the mamba_list_packages.txt file"
   echo "       This is not allowed. The offending package(s) are:"
   grep defaults mamba_list_packages.txt
   echo "       Please fix this and try again."
   exit 9
fi

cd "$SCRIPTDIR"
