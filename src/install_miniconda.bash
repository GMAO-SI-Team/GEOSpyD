#!/bin/bash

# -----
# Usage
# -----

EXAMPLE_PY_VERSION="3.9"
EXAMPLE_MINI_VERSION="4.10.3"
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
   echo "      --conda: Use conda installer"
   echo "      --help: Print this message"
   echo ""
   echo "  NOTE: This script installs within ${EXAMPLE_INSTALLDIR} with a path based on:"
   echo ""
   echo "        1. The Miniconda version"
   echo "        2. The Python version"
   echo "        3. The date of the installation"
   echo ""
   echo "  For example: $0 --python_version ${EXAMPLE_PY_VERSION} --miniconda_version ${EXAMPLE_MINI_VERSION} --prefix ${EXAMPLE_INSTALLDIR}"
   echo ""
   echo "  will create an install at:"
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

# -----------------
# Detect usual bits
# -----------------

ARCH=$(uname -s)
MACH=$(uname -m)
NODE=$(uname -n)

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

USE_CONDA=FALSE

while [[ -n "$1" ]]
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
         shift
         ;;
      --prefix)
         MINICONDA_DIR=$2
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

# ---------------------------
# Miniconda version variables
# ---------------------------

PYTHON_MAJOR_VERSION=${PYTHON_VER:0:1}
if [[ "$PYTHON_MAJOR_VERSION" != "2" && "$PYTHON_MAJOR_VERSION" != "3" ]]
then
   echo "Python version $PYTHON_VER implies Python major version $PYTHON_MAJOR_VERSION"
   echo "This script only supports Python 2 or 3"
   exit 2
fi
PYTHON_EXEC=python${PYTHON_MAJOR_VERSION}

MINICONDA_DISTVER=Miniconda${PYTHON_MAJOR_VERSION}

MINICONDA_SRCDIR=${SCRIPTDIR}/$MINICONDA_DISTVER

# --------------------------------------------------
# Test if we are in Python3-only Miniconda territory
# --------------------------------------------------

# https://unix.stackexchange.com/a/285928
LAST_SUPPORTED_PYTHON2="4.8.3"
LAST_SUPPORTED_PYTHON2_PLUS_1="4.8.4"
if [ "${PYTHON_MAJOR_VERSION}" == "2" ]
then
   if [ "$(printf '%s\n' "$LAST_SUPPORTED_PYTHON2_PLUS_1" "$MINICONDA_VER" | sort -V | head -n1)" = "$LAST_SUPPORTED_PYTHON2_PLUS_1" ]
   then
      echo "Miniconda only supports Python2 up to version ${LAST_SUPPORTED_PYTHON2}."
      echo "The passed-in version ${MINICONDA_VER} is larger than ${LAST_SUPPORTED_PYTHON2}"
      exit 2
   fi
fi

# ------------------------------
# Set the Miniconda Architecture
# ------------------------------

if [[ $ARCH == Darwin ]]
then
   MINICONDA_ARCH=MacOSX
else
   MINICONDA_ARCH=Linux
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

# Save user's .condarc for safety
if [[ -f ~/.condarc ]]
then
   cp -v ~/.condarc ~/.condarc-SAVE
fi

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

if [[ "$PYTHON_MAJOR_VERSION" == "2" ]]
then
   PROJ_LIB="proj4<6"
else
   PROJ_LIB="proj"
fi

conda_install conda

if [[ "$USE_CONDA" == "TRUE" ]]
then
   PACKAGE_INSTALL=conda_install
else
   conda_install mamba
   PACKAGE_INSTALL=mamba_install
fi

if [[ "$PYTHON_MAJOR_VERSION" == "3" ]]
then
   $PACKAGE_INSTALL esmpy
   $PACKAGE_INSTALL xesmf
   $PACKAGE_INSTALL pytest
   $PACKAGE_INSTALL xgcm
   $PACKAGE_INSTALL s3fs boto3
fi

$PACKAGE_INSTALL numpy scipy numba
$PACKAGE_INSTALL mkl mkl-service mkl_fft mkl_random tbb tbb4py intel-openmp
$PACKAGE_INSTALL netcdf4 basemap "$PROJ_LIB" matplotlib cartopy 
$PACKAGE_INSTALL virtualenv pipenv configargparse
$PACKAGE_INSTALL psycopg2 gdal xarray geotiff plotly
$PACKAGE_INSTALL iris pyhdf pip biggus hpccm cdsapi
$PACKAGE_INSTALL babel beautifulsoup4 colorama gmp jupyter jupyterlab
$PACKAGE_INSTALL pygrib f90nml seawater mo_pack libmo_unpack
$PACKAGE_INSTALL cmocean eofs pyspharm windspharm cubes
$PACKAGE_INSTALL pyasn1 redis redis-py ujson mdp configobj argcomplete biopython
$PACKAGE_INSTALL requests-toolbelt twine wxpython
$PACKAGE_INSTALL sockjs-tornado sphinx_rtd_theme django
$PACKAGE_INSTALL xgboost gooey pypng seaborn astropy
$PACKAGE_INSTALL fastcache get_terminal_size greenlet imageio jbig lzo
$PACKAGE_INSTALL mock sphinxcontrib pytables
$PACKAGE_INSTALL pydap

if [[ "$PYTHON_MAJOR_VERSION" == "3" ]]
then
   # This is only on python 3
   $PACKAGE_INSTALL timezonefinder
   $PACKAGE_INSTALL cython pythran
fi

# esmpy installs mpi. We don't want any of those in the bin dir
if [[ "$PYTHON_MAJOR_VERSION" == "3" ]]
then
   /bin/rm -v $MINICONDA_INSTALLDIR/bin/mpi*
fi
   
# We used to install cis, but it is too old; tries to downgrade matplotlib

# Many packages on Miniconda have no macOS or noarch version
# ---------------------------------------------------------

if [[ $MINICONDA_ARCH == Linux ]]
then
   # wgsiref is part of Python 3 now
   # -------------------------------
   if [[ "$PYTHON_MAJOR_VERSION" == "2" ]]
   then
      $PACKAGE_INSTALL wsgiref
   fi
fi

# Install weird nc_time_axis package
# ----------------------------------

$PACKAGE_INSTALL -c conda-forge/label/renamed nc_time_axis

# rtfw is the "replacement" for PyRTF. Install from pip
# -----------------------------------------------------

if [[ "$PYTHON_MAJOR_VERSION" == "2" ]]
then
   RTF_PACKAGE=rtfw
elif [[ "$PYTHON_MAJOR_VERSION" == "3" ]]
then
   RTF_PACKAGE=PyRTF3
else
   echo "Should not be here"
   exit 8
fi

PIP_INSTALL="$MINICONDA_BINDIR/$PYTHON_EXEC -m pip install"
$PIP_INSTALL $RTF_PACKAGE pipenv pymp-pypi rasterio theano blaze h5py

if [[ "$PYTHON_MAJOR_VERSION" == "3" ]]
then
   $PIP_INSTALL pycircleci metpy siphon questionary xgrads
fi

if [[ $ARCH == Linux ]]
then
   $PIP_INSTALL f90wrap
fi

# Finally pygrads is not even in pip, and only works for Python 2
# ---------------------------------------------------------------

if [[ "$PYTHON_MAJOR_VERSION" == "2" ]]
then
   tar xf $MINICONDA_SRCDIR/pygrads-1.1.9.tar.gz -C $MINICONDA_SRCDIR

   cd $MINICONDA_SRCDIR/pygrads-1.1.9

   $MINICONDA_BINDIR/$PYTHON_EXEC setup.py install

   # Inject code fix for spectral
   # ----------------------------
   find $MINICONDA_INSTALLDIR/lib -name 'gacm.py' -print0 | xargs -0 $SED -i -e '/cm.spectral,/ s/spectral/nipy_spectral/'
fi

# ffnet requires a Fortran compiler. This sometimes isn't available
$PIP_INSTALL ffnet

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

# Restore User's .condarc
# -----------------------
if [[ -f ~/.condarc-SAVE ]]
then
   mv -v ~/.condarc-SAVE ~/.condarc
else
   rm -v ~/.condarc
fi

cd $SCRIPTDIR
