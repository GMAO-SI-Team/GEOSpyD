#!/bin/bash

# -----
# Usage
# -----

EXAMPLE_PY_VERSION="3.7"
EXAMPLE_ANA_VERSION="2019.03"
EXAMPLE_INSTALLDIR="/opt/GEOSpyD"
EXAMPLE_DATE=$(date +%F)
usage() {
   echo "Usage: $0 --python_version <python version> --anaconda_version <anaconda_version> --prefix <prefix>"
   echo ""
   echo "   Required arguments:"
   echo "      --python_version <python version> (e.g., ${EXAMPLE_PY_VERSION})"
   echo "      --anaconda_version <anaconda version> (e.g., ${EXAMPLE_ANA_VERSION})"
   echo "      --prefix <full path to installation directory> (e.g, ${EXAMPLE_INSTALLDIR})"
   echo ""
   echo "   Optional arguments:"
   echo "      --help: Print this message"
   echo ""
   echo "  NOTE: This script installs within ${EXAMPLE_INSTALLDIR} with a path based on:"
   echo ""
   echo "        1. The Anaconda version"
   echo "        2. The Python version"
   echo "        3. The date of the installation"
   echo ""
   echo "  For example: $0 --python_version ${EXAMPLE_PY_VERSION} --anaconda_version ${EXAMPLE_ANA_VERSION} --prefix ${EXAMPLE_INSTALLDIR}"
   echo ""
   echo "  will create an install at:"
   echo "       ${EXAMPLE_INSTALLDIR}/${EXAMPLE_ANA_VERSION}_py${EXAMPLE_PY_VERSION}/${EXAMPLE_DATE}"
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
      --anaconda_version)
         ANACONDA_VER=$2
         shift
         ;;
      --prefix)
         ANACONDA_DIR=$2
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

if [[ -z $ANACONDA_VER ]]
then
   echo "ERROR: Anaconda version not sent in"
   usage
   exit 1
fi

if [[ -z $ANACONDA_DIR ]]
then
   echo "ERROR: Anaconda installation directory not sent in"
   usage
   exit 1
fi

# --------------------------
# Anaconda version variables
# --------------------------

PYTHON_MAJOR_VERSION=${PYTHON_VER:0:1}
if [[ "$PYTHON_MAJOR_VERSION" != "2" && "$PYTHON_MAJOR_VERSION" != "3" ]]
then
   echo "Python version $PYTHON_VER implies Python major version $PYTHON_MAJOR_VERSION"
   echo "This script only supports Python 2 or 3"
   exit 2
fi
PYTHON_EXEC=python${PYTHON_MAJOR_VERSION}

ANACONDA_DISTVER=Anaconda${PYTHON_MAJOR_VERSION}

ANACONDA_SRCDIR=${SCRIPTDIR}/$ANACONDA_DISTVER

# -----------------------------
# Set the Anaconda Architecture
# -----------------------------

if [[ $ARCH == Darwin ]]
then
   ANACONDA_ARCH=MacOSX
else
   ANACONDA_ARCH=Linux
fi

#------------------------------------------------------
# Create the installtion directory if it does not exist
#------------------------------------------------------
if [ ! -d "$ANACONDA_DIR" ]
then
   mkdir -p $ANACONDA_DIR
fi

DATE=$(date +%F)
ANACONDA_INSTALLDIR=$ANACONDA_DIR/${ANACONDA_VER}_py${PYTHON_VER}/$DATE

INSTALLER=${ANACONDA_DISTVER}-${ANACONDA_VER}-${ANACONDA_ARCH}-${MACH}.sh

echo "ANACONDA_SRCDIR     = $ANACONDA_SRCDIR"
echo "INSTALLER           = $ANACONDA_SRCDIR/$INSTALLER"
echo "Anaconda will be installed in $ANACONDA_INSTALLDIR"

if [[ -d $ANACONDA_INSTALLDIR ]]
then
   echo "ERROR: $ANACONDA_INSTALLDIR already exists! Exiting!"
   exit 9
fi

if [[ ! -f $ANACONDA_SRCDIR/$INSTALLER ]]
then
   REPO=https://repo.anaconda.com/archive
   (cd $ANACONDA_SRCDIR; curl -O $REPO/$INSTALLER)
fi

bash $ANACONDA_SRCDIR/$INSTALLER -b -p $ANACONDA_INSTALLDIR

ANACONDA_BINDIR=$ANACONDA_INSTALLDIR/bin

# Now install regular conda packages
# ----------------------------------

$ANACONDA_BINDIR/conda install -y netcdf4 cartopy cubes krb5 \
   pyasn1 redis redis-py ujson mdp configobj blaze argcomplete biopython \
   sockjs-tornado sphinx_rtd_theme virtualenv django mock psycopg2 \
   requests-toolbelt twine wxpython configargparse \
   xarray geotiff gdal plotly theano

# Many packages on Anaconda have no macOS or noarch version
# ---------------------------------------------------------

if [[ $ANACONDA_ARCH == Linux ]]
then
   # wgsiref is part of Python 3 now
   # -------------------------------
   if [[ "$PYTHON_MAJOR_VERSION" == "2" ]]
   then
      $ANACONDA_BINDIR/conda install -y wsgiref
   fi
fi

$ANACONDA_BINDIR/conda install -y -c conda-forge conda

# Install weird nc_time_axis package
# ----------------------------------

$ANACONDA_BINDIR/conda install -y -c conda-forge/label/renamed nc_time_axis

# Install conda-forge packages
# ----------------------------

$ANACONDA_BINDIR/conda install -y -c conda-forge conda

$ANACONDA_BINDIR/conda install -y -c conda-forge iris pyhdf basemap \
   eofs pyspharm windspharm mo_pack \
   libmo_unpack f90nml seawater biggus \
   cmocean pip cdsapi xgboost gooey hpccm \
   xorg-libx11 xorg-kbproto xorg-xproto xorg-xextproto \
   xorg-libxrender xorg-renderproto xorg-libice \
   xorg-libxext

################################################################
# # These packages cannot be installed by 2019.10 at this time #
# $ANACONDA_BINDIR/conda install -y -c conda-forge \           #
#    pygrib \                                                  #
#    xorg-libsm \                                              #
#    cis                                                       #
################################################################

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

$ANACONDA_BINDIR/$PYTHON_EXEC -m pip install $RTF_PACKAGE pipenv ffnet f90wrap

# Finally pygrads is not even in pip, and only works for Python 2
# ---------------------------------------------------------------

if [[ "$PYTHON_MAJOR_VERSION" == "2" ]]
then
   tar xf $ANACONDA_SRCDIR/pygrads-1.1.9.tar.gz -C $ANACONDA_SRCDIR

   cd $ANACONDA_SRCDIR/pygrads-1.1.9

   $ANACONDA_BINDIR/$PYTHON_EXEC setup.py install
fi

cd $SCRIPTDIR

# Inject Joe Stassi's f2py shell fix into numpy
# ---------------------------------------------
find $ANACONDA_INSTALLDIR/lib -name 'exec_command.py' -print0 | xargs -0 $SED -i -e 's#^\( *\)use_shell = False#&\n\1command.insert(1, "-f")#'

# Inject fix for Intel compiler in new numpy (1.16+) which uses subprocess now instead of exec_command.py
# -------------------------------------------------------------------------------------------------------
find $ANACONDA_INSTALLDIR/lib/python?.?/site-packages -name 'ccompiler.py' -print0 | xargs -0 $SED -i -e '/output = subprocess.check_output(version_cmd)/ s/version_cmd/version_cmd, stderr=subprocess.STDOUT/'

# Edit matplotlibrc to use TkAgg as the default backend for matplotlib
# as that is the only backend that seems supported on all systems
# --------------------------------------------------------------------
find $ANACONDA_INSTALLDIR/lib -name 'matplotlibrc' -print0 | xargs -0 $SED -i -e '/^backend/ s#\(backend *:\).*#\1 TkAgg#'

# Use conda to output list of packages installed
# ----------------------------------------------
cd $ANACONDA_INSTALLDIR
./bin/conda list --explicit > distribution_spec_file.txt
./bin/conda list > conda_list_packages.txt
