#!/bin/bash

# -----
# Usage
# -----

EXAMPLE_PY_VERSION="3.7"
EXAMPLE_MINI_VERSION="4.7.12.1"
EXAMPLE_INSTALLDIR="/opt/GEOSpyD"
EXAMPLE_DATE=$(date +%F)
usage() {
   echo "Usage: $0 --python_version <python version> --miniconda_version <miniconda_version> --prefix <prefix>"
   echo ""
   echo "   Required arguments:"
   echo "      --python_version <python version> (e.g., ${EXAMPLE_PY_VERSION})"
   echo "      --miniconda_version <miniconda_version version> (e.g., ${EXAMPLE_MINI_VERSION})"
   echo "      --prefix <full path to installation directory> (e.g, ${EXAMPLE_INSTALLDIR})"
   echo ""
   echo "   Optional arguments:"
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

if [[ $NODE =~ discover* || $NODE =~ borg* ]]
then
   SITE=NCCS
elif [[ $NODE =~ pfe* || $NODE =~ r[0-9]*i[0-9]*n[0-9]* ]]
then
   SITE=NAS
elif [[ -d /ford1/share/gmao_SIteam && -d /ford1/local && $ARCH == Linux ]]
then
   SITE=GMAO.desktop
else
   SITE=UNKNOWN
fi

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

# --------------------------
# Miniconda version variables
# --------------------------

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

# -----------------------------
# Set the Miniconda Architecture
# -----------------------------

if [[ $ARCH == Darwin ]]
then
   MINICONDA_ARCH=MacOSX
else
   MINICONDA_ARCH=Linux
fi

#------------------------------------------------------
# Create the installtion directory if it does not exist
#------------------------------------------------------
if [ ! -d "$MINICONDA_DIR" ]
then
   mkdir -p $MINICONDA_DIR
fi

DATE=$(date +%F)
MINICONDA_INSTALLDIR=$MINICONDA_DIR/${MINICONDA_VER}_py${PYTHON_VER}/$DATE

INSTALLER=${MINICONDA_DISTVER}-${MINICONDA_VER}-${MINICONDA_ARCH}-${MACH}.sh

echo "MINICONDA_SRCDIR     = $MINICONDA_SRCDIR"
echo "INSTALLER           = $MINICONDA_SRCDIR/$INSTALLER"
echo "Miniconda will be installed in $MINICONDA_INSTALLDIR"

if [[ -d $MINICONDA_INSTALLDIR ]]
then
   echo "ERROR: $MINICONDA_INSTALLDIR already exists! Exiting!"
   exit 9
fi

if [[ ! -f $MINICONDA_SRCDIR/$INSTALLER ]]
then
   REPO=https://repo.anaconda.com/miniconda
   (cd $MINICONDA_SRCDIR; curl -O $REPO/$INSTALLER)
fi

bash $MINICONDA_SRCDIR/$INSTALLER -b -p $MINICONDA_INSTALLDIR

MINICONDA_BINDIR=$MINICONDA_INSTALLDIR/bin

# Now install regular conda packages
# ----------------------------------

CONDA_INSTALL="$MINICONDA_BINDIR/conda install -y"

$CONDA_INSTALL conda

$CONDA_INSTALL numpy scipy numba
$CONDA_INSTALL mkl mkl-service mkl_fft mkl_random tbb tbb4py intel-openmp
$CONDA_INSTALL netcdf4 basemap matplotlib cartopy virtualenv pipenv configargparse
$CONDA_INSTALL psycopg2 gdal xarray geotiff plotly
$CONDA_INSTALL iris pyhdf pip biggus hpccm cdsapi
$CONDA_INSTALL babel beautifulsoup4 colorama gmp jupyter jupyterlab
$CONDA_INSTALL pygrib f90nml seawater mo_pack libmo_unpack
$CONDA_INSTALL cmocean eofs pyspharm windspharm cubes
$CONDA_INSTALL pyasn1 redis redis-py ujson mdp configobj argcomplete biopython
$CONDA_INSTALL requests-toolbelt twine wxpython
$CONDA_INSTALL sockjs-tornado sphinx_rtd_theme django
$CONDA_INSTALL xgboost gooey pypng seaborn astropy
$CONDA_INSTALL fastcache get_terminal_size greenlet imageio jbig lzo
$CONDA_INSTALL mock sphinxcontrib pytables
   
# cis is too old; tries to downgrade matplotlib

# Many packages on Miniconda have no macOS or noarch version
# ---------------------------------------------------------

if [[ $MINICONDA_ARCH == Linux ]]
then
   # wgsiref is part of Python 3 now
   # -------------------------------
   if [[ "$PYTHON_MAJOR_VERSION" == "2" ]]
   then
      $CONDA_INSTALL wsgiref
   fi
fi

# Install weird nc_time_axis package
# ----------------------------------

$CONDA_INSTALL -c conda-forge/label/renamed nc_time_axis

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
$PIP_INSTALL $RTF_PACKAGE pipenv ffnet pymp-pypi rasterio theano blaze h5py

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
fi

cd $SCRIPTDIR

# Inject Joe Stassi's f2py shell fix into numpy
# ---------------------------------------------
find $MINICONDA_INSTALLDIR/lib -name 'exec_command.py' -print0 | xargs -0 $SED -i -e 's#^\( *\)use_shell = False#&\n\1command.insert(1, "-f")#'

# Inject fix for Intel compiler in new numpy (1.16+) which uses subprocess now instead of exec_command.py
# -------------------------------------------------------------------------------------------------------
#find $MINICONDA_INSTALLDIR/lib/python?.?/site-packages -name 'ccompiler.py' -print0 | xargs -0 $SED -i -e '/output = subprocess.check_output(version_cmd)/ s/version_cmd/version_cmd, stderr=subprocess.STDOUT/'

# Edit matplotlibrc to use TkAgg as the default backend for matplotlib
# as that is the only backend that seems supported on all systems
# --------------------------------------------------------------------
find $MINICONDA_INSTALLDIR/lib -name 'matplotlibrc' -print0 | xargs -0 $SED -i -e '/^.*backend/ s%.*\(backend *:\).*%\1 TkAgg%'

# Use conda to output list of packages installed
# ----------------------------------------------
cd $MINICONDA_INSTALLDIR
./bin/conda list --explicit > distribution_spec_file.txt
./bin/conda list > conda_list_packages.txt

cd $SCRIPTDIR
