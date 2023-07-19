#!/bin/bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

# Save user's .condarc for safety using mktemp
# ---------------------------------------------

ORIG_CONDARC=$(mktemp)
CONDARC_FOUND=FALSE
if [[ -f ~/.condarc ]]
then
   CONDARC_FOUND=TRUE
   cp -v ~/.condarc $ORIG_CONDARC
fi

# The cleanup function will restore the user's .condarc
# -----------------------------------------------------
cleanup() {
   trap - SIGINT SIGTERM ERR EXIT
   local ret=$?
   echo "Cleaning up..."
   if [[ $CONDARC_FOUND == TRUE ]]
   then
      echo "Restoring original .condarc"
      cp -v $ORIG_CONDARC ~/.condarc
   fi
   exit $ret
}

# -----------------
# Detect usual bits
# -----------------

ARCH=$(uname -s)
MACH=$(uname -m)
NODE=$(uname -n)

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

EXAMPLE_PY_VERSION="3.11"
EXAMPLE_MINI_VERSION="25.3.0-3"
EXAMPLE_INSTALLDIR="/opt/GEOSpyD"
EXAMPLE_DATE=$(date +%F)
usage() {
   echo "Usage: $0 --python_version <python version> --miniconda_version <miniconda_version> --prefix <prefix> [--conda]"
   echo ""
   echo "   Required arguments:"
   echo "      --python_version <python version> (e.g., ${EXAMPLE_PY_VERSION})"
   echo "      --miniconda_version <miniconda_version version> (e.g., ${EXAMPLE_MINI_VERSION})"
   echo "      --prefix <full path to installation directory> (e.g, ${EXAMPLE_INSTALLDIR})"
   echo ""
   echo "   Optional arguments:"
   echo "      --blas <blas> (default: ${BLAS_IMPL}, options: mkl, openblas, accelerate)"
   echo "      --conda: Use conda installer"
   echo "      --mamba: Use mamba installer"
   echo "      --micromamba: Use micromamba installer"
   echo "      --help: Print this message"
   echo ""
   echo "   By default we use the micromamba installer on macOS and mamba on Linux"
   echo ""
   echo "   NOTE: This script installs within ${EXAMPLE_INSTALLDIR} with a path based on:"
   echo ""
   echo "        1. The Miniconda version"
   echo "        2. The Python version"
   echo "        3. The date of the installation"
   echo ""
   echo "   For example: $0 --python_version ${EXAMPLE_PY_VERSION} --miniconda_version ${EXAMPLE_MINI_VERSION} --prefix ${EXAMPLE_INSTALLDIR}"
   echo ""
   echo "   will create an install at:"
   echo "       ${EXAMPLE_INSTALLDIR}/${EXAMPLE_MINI_VERSION}_py${EXAMPLE_PY_VERSION}/${EXAMPLE_DATE}"
}

if [[ $# -lt 4 ]]
then
   usage
   exit 1
fi

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
      SED="$(command -v gsed) -i "
   else
      #echo "It is recommended to use GNU sed since macOS default"
      #echo "sed is a useless BSD variant. Consider installing"
      #echo "GNU sed from a packager like Homebrew:"
      #echo "  brew install gnu-sed"
      SED="$(command -v sed) -i.macbak "
   fi
else
   SED="$(command -v sed) -i "
fi

# ----------------------
# Command line arguments
# ----------------------

if [[ $ARCH == Darwin ]]
then
   USE_CONDA=FALSE
   USE_MAMBA=FALSE
   USE_MICROMAMBA=TRUE
else
   USE_CONDA=FALSE
   USE_MAMBA=TRUE
   USE_MICROMAMBA=FALSE
fi

while [[ $# -gt 0 ]]
do
   case "$1" in
      --python_version)
         PYTHON_VER=$2
         shift
         ;;
      --miniconda_version)
         MINICONDA_VER=$2
         shift
         ;;
      --conda)
         USE_CONDA=TRUE
         USE_MAMBA=FALSE
         USE_MICROMAMBA=FALSE
         ;;
      --mamba)
         USE_CONDA=FALSE
         USE_MAMBA=TRUE
         USE_MICROMAMBA=FALSE
         ;;
      --micromamba)
         USE_CONDA=FALSE
         USE_MAMBA=FALSE
         USE_MICROMAMBA=TRUE
         ;;
      --prefix)
         MINICONDA_DIR=$2
         shift
         ;;
      --blas)
         BLAS_IMPL=$2
         shift
         ;;
      --help | -h)
         usage
         exit 1
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

if [[ -z $MINICONDA_VER ]]
then
   echo "ERROR: Miniconda version not sent in"
   usage
   exit 1
fi

if [[ -z $MINICONDA_DIR ]]
then
   echo "ERROR: Miniconda installation directory not sent in"
   usage
   exit 1
fi

# We will only allow BLAS_IMPL to be: mkl, openblas, accelerate
if [[ $BLAS_IMPL != mkl && $BLAS_IMPL != openblas && $BLAS_IMPL != accelerate ]]
then
   echo "ERROR: BLAS implementation $BLAS_IMPL not recognized"
   usage
   exit 1
fi


# On Linux we will install ffnet which now seems to require a Fortran
# compiler and for portability's sake we require gfortran. Moreover, we
# require that gfortran be at least version 8.3.0.
#
# We'll do the test now as to not waste time if the user has a
# too-old gfortran.

if [[ $ARCH == Linux ]]
then
   # We need to check if gfortran is available and if so, what version
   # it is. If it is not available or if it is too old, we need to
   # error out and tell the user to either install it or load an
   # appropriate module.

   # First check if gfortran is available
   # ------------------------------------

   if [[ -z $(which gfortran) ]]
   then
      echo "ERROR: gfortran is not available. Please install it or load an appropriate module."
      echo "       We require at least version 8.3.0 to install ffnet"
      exit 9
   fi

   # Now check the version
   # ---------------------

   # First get the version string as the last field of the first
   # line of the output of gfortran --version
   GFORTRAN_VERSION=$(gfortran --version | head -n 1 | awk '{print $NF}')

   # Now split the version string into its components
   # and capture the major, minor, and patch versions
   GFORTRAN_MAJOR=$(echo $GFORTRAN_VERSION | awk -F. '{print $1}')
   GFORTRAN_MINOR=$(echo $GFORTRAN_VERSION | awk -F. '{print $2}')
   GFORTRAN_PATCH=$(echo $GFORTRAN_VERSION | awk -F. '{print $3}')

   if [[ $GFORTRAN_MAJOR -lt 8 ]]
   then
      echo "ERROR: gfortran is too old. Please install at least version 8.3.0 or load an appropriate module."
      exit 9
   fi

   if [[ $GFORTRAN_MINOR -lt 3 ]]
   then
      echo "ERROR: gfortran is too old. Please install at least version 8.3.0 or load an appropriate module."
      exit 9
   fi

   # At this point we know that gfortran is available and that it is
   # at least version 8.3.0. So we can install ffnet.
fi

# ---------------------------
# Miniconda version variables
# ---------------------------

PYTHON_MAJOR_VERSION=${PYTHON_VER:0:1}
if [[ "$PYTHON_MAJOR_VERSION" != "3" ]]
then
   echo "Python version $PYTHON_VER implies Python major version $PYTHON_MAJOR_VERSION"
   echo "This script only supports Python 3"
   exit 2
fi
PYTHON_EXEC=python${PYTHON_MAJOR_VERSION}

MINICONDA_DISTVER=Miniconda${PYTHON_MAJOR_VERSION}

MINICONDA_SRCDIR=${SCRIPTDIR}/$MINICONDA_DISTVER

# ------------------------------
# Set the Miniconda Architecture
# ------------------------------

if [[ $ARCH == Darwin ]]
then
   MINICONDA_ARCH=MacOSX
   if [[ $MACH == arm64 ]]
   then
      MICROMAMBA_ARCH=osx-arm64
      # Note: accelerate might have issues with scipy
      #       See https://github.com/conda-forge/numpy-feedstock/issues/253
   else
      MICROMAMBA_ARCH=osx-64
   fi
else
   MINICONDA_ARCH=Linux
   MICROMAMBA_ARCH=linux-64
fi

# -----------------------------------------------------
# Create the installtion directory if it does not exist
# -----------------------------------------------------

if [ ! -d "$MINICONDA_DIR" ]
then
   mkdir -p $MINICONDA_DIR
fi

DATE=$(date +%F)
MINICONDA_INSTALLDIR=$MINICONDA_DIR/${MINICONDA_VER}_py${PYTHON_VER}/$DATE

if [[ "$MINICONDA_VER" == "latest" ]]
then
   CANONICAL_INSTALLER=${MINICONDA_DISTVER}-${MINICONDA_VER}-${MINICONDA_ARCH}-${MACH}.sh
   DATED_INSTALLER=${MINICONDA_DISTVER}-${MINICONDA_VER}-${MINICONDA_ARCH}-${MACH}.${DATE}.sh
else
   PYTHON_VER_WITHOUT_DOT="${PYTHON_VER//./}"
   CANONICAL_INSTALLER=${MINICONDA_DISTVER}-py${PYTHON_VER_WITHOUT_DOT}_${MINICONDA_VER}-${MINICONDA_ARCH}-${MACH}.sh
fi

echo "MINICONDA_SRCDIR     = $MINICONDA_SRCDIR"
echo "CANONICAL_INSTALLER  = $MINICONDA_SRCDIR/$CANONICAL_INSTALLER"
if [[ "$MINICONDA_VER" == "latest" ]]
then
   echo "DATED_INSTALLER      = $MINICONDA_SRCDIR/$DATED_INSTALLER"
fi
echo "Miniconda will be installed in $MINICONDA_INSTALLDIR"

if [[ -d $MINICONDA_INSTALLDIR ]]
then
   echo "ERROR: $MINICONDA_INSTALLDIR already exists! Exiting!"
   exit 9
fi

if [[ ! -f $MINICONDA_SRCDIR/$CANONICAL_INSTALLER ]]
then
   REPO=https://repo.anaconda.com/miniconda
   (cd $MINICONDA_SRCDIR; curl -O $REPO/$CANONICAL_INSTALLER)
fi

if [[ "$MINICONDA_VER" == "latest" ]]
then
   mv -v $MINICONDA_SRCDIR/$CANONICAL_INSTALLER $MINICONDA_SRCDIR/$DATED_INSTALLER
   INSTALLER=$DATED_INSTALLER
else
   INSTALLER=$CANONICAL_INSTALLER
fi

# NOTE: We have to use strict conda-forge channel
# -----------------------------------------------

# Now create the good one (we restore the old one at the end)
cat << EOF > ~/.condarc
# Temporary condarc from install_miniconda.bash
channels:
  - conda-forge
  - defaults
channel_priority: strict
EOF

# -----------------
# Install Miniconda
# -----------------

bash $MINICONDA_SRCDIR/$INSTALLER -b -p $MINICONDA_INSTALLDIR

MINICONDA_BINDIR=$MINICONDA_INSTALLDIR/bin

# Now install regular conda packages
# ----------------------------------

function conda_install {
   CONDA_INSTALL_COMMAND="$MINICONDA_BINDIR/conda install -y"

   echo
   echo "(conda) Now installing $*"
   $CONDA_INSTALL_COMMAND $*
   echo
}

function mamba_install {
   MAMBA_INSTALL_COMMAND="$MINICONDA_BINDIR/mamba install -y"

   echo
   echo "(mamba) Now installing $*"
   $MAMBA_INSTALL_COMMAND $*
   echo
}

function micromamba_install {
   MICROMAMBA_INSTALL_COMMAND="$MINICONDA_BINDIR/micromamba -p $MINICONDA_INSTALLDIR install -y"

   echo
   echo "(micromamba) Now installing $*"
   $MICROMAMBA_INSTALL_COMMAND $*
   echo
}

if [[ "$USE_CONDA" == "TRUE" ]]
then
   echo "=== Using conda as package manager ==="

   PACKAGE_INSTALL=conda_install

   # Update conda
   $MINICONDA_BINDIR/conda update -y -n base -c defaults conda

elif [[ "$USE_MICROMAMBA" == "TRUE" ]]
then
   echo "=== Using micromamba as package manager ==="

   PACKAGE_INSTALL=micromamba_install

   # We also need to fetch micromamba
   # --------------------------------

   echo "=== Installing micromamba ==="
   MICROMAMBA_URL="https://micro.mamba.pm/api/micromamba/${MICROMAMBA_ARCH}/latest"
   curl -Ls ${MICROMAMBA_URL} | tar -C $MINICONDA_INSTALLDIR -xvj bin/micromamba
elif [[ "$USE_MAMBA" == "TRUE" ]]
then
   echo "=== Using mamba as package manager ==="

   conda_install mamba
   PACKAGE_INSTALL=mamba_install
else
   echo "ERROR: No package manager selected! We should not get here. Exiting!"
   exit 9
fi

# --------------------
# CONDA/MAMBA PACKAGES
# --------------------

echo "BLAS_IMPL: $BLAS_IMPL"
$PACKAGE_INSTALL "libblas=*=*${BLAS_IMPL}"

# in libcxx 14.0.6 (from miniconda), __string is a file, but in 16.0.6
# it is a directory so, in order for libcxx to be updated, we have to
# remove it because the updater will fail
#
# This seems to only happen on macOS

if [[ $ARCH == Darwin ]]
then
   # First let's check the version of libcxx installed by asking conda

   LIBCXX_VERSION=$($MINICONDA_INSTALLDIR/bin/conda list libcxx | grep libcxx | awk '{print $2}')

   # This is the version X.Y.Z and we want to do things only if X is 14 as it's a directory in 15+
   # Let's use bash to extract the first number
   LIBCXX_MAJOR_VERSION=${LIBCXX_VERSION%%.*}
   MINICONDA_MAJOR_VERSION=${MINICONDA_VER%%.*}

   if [[ $LIBCXX_MAJOR_VERSION -lt 15 && $MINICONDA_MAJOR_VERSION -ge 23 ]]
   then
      if [[ -f $MINICONDA_INSTALLDIR/include/c++/v1/__string ]]
      then
         echo "Removing $MINICONDA_INSTALLDIR/include/c++/v1/__string"
         rm $MINICONDA_INSTALLDIR/include/c++/v1/__string
      fi
   fi
fi

$PACKAGE_INSTALL esmpy
$PACKAGE_INSTALL xesmf
$PACKAGE_INSTALL pytest
$PACKAGE_INSTALL xgcm
$PACKAGE_INSTALL s3fs boto3

$PACKAGE_INSTALL numpy scipy numba
$PACKAGE_INSTALL netcdf4 cartopy proj matplotlib
$PACKAGE_INSTALL virtualenv pipenv configargparse
$PACKAGE_INSTALL psycopg2 gdal xarray geotiff plotly
$PACKAGE_INSTALL iris pyhdf pip biggus hpccm cdsapi
$PACKAGE_INSTALL babel beautifulsoup4 colorama gmp jupyter jupyterlab
# We need to pin hvplot due to https://github.com/movingpandas/movingpandas/issues/326
# We need to pin bokeh as geoviews does not work with bokeh 3.2
$PACKAGE_INSTALL movingpandas geoviews hvplot=0.8.3 geopandas bokeh=3.1
$PACKAGE_INSTALL intake intake-parquet intake-xarray

# Looks like mo_pack, libmo_pack, pyspharm, windspharm are not available on arm64
if [[ $MACH == arm64 ]]
then
   $PACKAGE_INSTALL pygrib f90nml seawater
   $PACKAGE_INSTALL cmocean eofs
else
   $PACKAGE_INSTALL pygrib f90nml seawater mo_pack libmo_unpack
   # Next it looks like pyspharm and windspharm are not available for Python 3.11
   if [[ $PYTHON_VER_WITHOUT_DOT -lt 311 ]]
   then
      $PACKAGE_INSTALL cmocean eofs pyspharm windspharm
   else
      $PACKAGE_INSTALL cmocean eofs
   fi
fi

$PACKAGE_INSTALL pyasn1 redis redis-py ujson configobj argcomplete biopython
# mdp only exists from 3.10 and older
if [[ $PYTHON_VER_WITHOUT_DOT -le 310 ]]
then
   $PACKAGE_INSTALL mdp
fi
$PACKAGE_INSTALL requests-toolbelt twine wxpython
$PACKAGE_INSTALL sockjs-tornado sphinx_rtd_theme django
$PACKAGE_INSTALL pypng seaborn astropy
$PACKAGE_INSTALL fastcache greenlet imageio jbig lzo
# get_terminal_size are not on arm64
if [[ $MACH != arm64 ]]
then
   $PACKAGE_INSTALL get_terminal_size
fi
$PACKAGE_INSTALL mock sphinxcontrib pytables
$PACKAGE_INSTALL pydap
$PACKAGE_INSTALL gsw

$PACKAGE_INSTALL timezonefinder
$PACKAGE_INSTALL cython
$PACKAGE_INSTALL wordcloud
$PACKAGE_INSTALL zarr

$PACKAGE_INSTALL scikit-learn

$PACKAGE_INSTALL yamllint
$PACKAGE_INSTALL verboselogs

# Only install pythran on linux. On mac it brings in an old clang
if [[ $MINICONDA_ARCH == Linux ]]
then
   $PACKAGE_INSTALL pythran
fi

# esmpy installs mpi. We don't want any of those in the bin dir
# so we rename and relink. First we rename the files:

cd $MINICONDA_INSTALLDIR/bin

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

cd $SCRIPTDIR

# Install weird nc_time_axis package
# ----------------------------------
$PACKAGE_INSTALL -c conda-forge/label/renamed nc_time_axis

# ------------
# PIP PACKAGES
# ------------

PIP_INSTALL="$MINICONDA_BINDIR/$PYTHON_EXEC -m pip install"
$PIP_INSTALL PyRTF3 pipenv pymp-pypi rasterio theano blaze h5py
$PIP_INSTALL pycircleci metpy siphon questionary xgrads
$PIP_INSTALL ruamel.yaml
$PIP_INSTALL xgboost
$PIP_INSTALL tensorflow evidential-deep-learning silence_tensorflow
$PIP_INSTALL yaplon
$PIP_INSTALL lxml

# some packages require a Fortran compiler. This sometimes isn't available
# on macs (though usually is)
if [[ $ARCH == Linux ]]
then
   $PIP_INSTALL f90wrap
   # we need to install ffnet from https://github.com/mrkwjc/ffnet.git
   # This is because the version in PyPI is not compatible with Python 3
   # and latest scipy
   $PIP_INSTALL git+https://github.com/mrkwjc/ffnet
fi

# Finally pygrads is not in pip
# -----------------------------

PYGRADS_VERSION="pygrads-3.0.b1"
if [[ -d $MINICONDA_SRCDIR/$PYGRADS_VERSION ]]
then
   rm -rf $MINICONDA_SRCDIR/$PYGRADS_VERSION
fi

tar xf $MINICONDA_SRCDIR/$PYGRADS_VERSION.tar.gz -C $MINICONDA_SRCDIR

cd $MINICONDA_SRCDIR/$PYGRADS_VERSION

$MINICONDA_BINDIR/$PYTHON_EXEC setup.py install

# Inject code fix for spectral
# ----------------------------
find $MINICONDA_INSTALLDIR/lib -name 'gacm.py' -print0 | xargs -0 $SED -i -e '/cm.spectral,/ s/spectral/nipy_spectral/'

cd $SCRIPTDIR

# Inject Joe Stassi's f2py shell fix into numpy
# ---------------------------------------------
find $MINICONDA_INSTALLDIR/lib -name 'exec_command.py' -print0 | xargs -0 $SED -i -e 's#^\( *\)use_shell = False#&\n\1command.insert(1, "-f")#'

# Edit matplotlibrc to use TkAgg as the default backend for matplotlib
# as that is the only backend that seems supported on all systems
# --------------------------------------------------------------------
find $MINICONDA_INSTALLDIR/lib -name 'matplotlibrc' -print0 | xargs -0 $SED -i -e '/^.*backend/ s%.*\(backend *:\).*%\1 TkAgg%'

# Use conda to output list of packages installed
# ----------------------------------------------
cd $MINICONDA_INSTALLDIR
./bin/conda list --explicit > distribution_spec_file.txt
./bin/conda list > conda_list_packages.txt
./bin/pip freeze > pip_freeze_packages.txt

# Restore User's .condarc using cleanup function
# ----------------------------------------------
cleanup

cd $SCRIPTDIR

