#!/bin/bash -x

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

if [[ $ARCH == Darwin ]]
then
   ANACONDA_ARCH=MacOSX
else
   ANACONDA_ARCH=Linux
fi

# --------------------------
# Anaconda version variables
# --------------------------

ANACONDA_DISTVER=Anaconda2
ANACONDA_VER=5.3.1
PYTHON_VER=2.7

# -----------------------------------------------------------
# Location of the Anaconda2 sh installer -- System Dependent!
# -----------------------------------------------------------
ANACONDA_DIR=/ford1/share/gmao_SIteam/anaconda
#NCCS ANACONDA_DIR=/discover/swdev/mathomp4/anaconda
#NAS  ANACONDA_DIR=/nobackup/gmao_SIteam/anaconda
#ANACONDA_DIR=$HOME/anaconda

ANACONDA_SRCDIR=$ANACONDA_DIR/src/$ANACONDA_DISTVER
DATE=$(date +%F)

ANACONDA_INSTALLDIR=$ANACONDA_DIR/$ANACONDA_VER/$PYTHON_VER/$DATE

INSTALLER=${ANACONDA_DISTVER}-${ANACONDA_VER}-${ANACONDA_ARCH}-${MACH}.sh

if [[ ! -f $ANACONDA_SRCDIR/$INSTALLER ]]
then
   REPO=https://repo.anaconda.com/archive
   curl -O $REPO/$INSTALLER
fi

bash $ANACONDA_SRCDIR/$INSTALLER -b -p $ANACONDA_INSTALLDIR

ANACONDA_BINDIR=$ANACONDA_INSTALLDIR/bin

# Now install regular conda packages
# ----------------------------------

# MAT Blaze-core seems superseded by blaze
#     ipython-notebook seems superseded by jupyter

$ANACONDA_BINDIR/conda install -y mpi4py netcdf4 cartopy cubes krb5 pyasn1 redis redis-py ujson mdp configobj blaze argcomplete biopython launcher sockjs-tornado sphinx_rtd_theme virtualenv django mock psycopg2 requests-toolbelt twine wxpython

# Many packages on Anaconda have no macOS or noarch version
# ---------------------------------------------------------

if [[ $ANACONDA_ARCH == Linux ]]
then
   $ANACONDA_BINDIR/conda install -y util-linux

   $ANACONDA_BINDIR/conda install -y wsgiref
fi

# Install weird nc_time_axis package
# ----------------------------------

$ANACONDA_BINDIR/conda install -y -c conda-forge/label/renamed nc_time_axis

# Install conda-forge packages
# ----------------------------

$ANACONDA_BINDIR/conda install -y -c conda-forge iris pyhdf basemap geotiff gdal f90wrap eofs joblib pyspharm windspharm mo_pack libmo_unpack f90nml pygrib seawater biggus plotly theano matplotlib tk xorg-kbproto xorg-libice xorg-libsm xorg-libx11 xorg-libxext xorg-libxrender xorg-renderproto xorg-xextproto xorg-xproto xarray

# rtfw is the "replacement" for PyRTF. Install from pip
# -----------------------------------------------------

$ANACONDA_BINDIR/python2 -m pip install rtfw pipenv ffnet

# Finally pygrads is not even in pip
# ----------------------------------

tar xf $ANACONDA_SRCDIR/pygrads-1.1.9.tar.gz -C $ANACONDA_SRCDIR

cd $ANACONDA_SRCDIR/pygrads-1.1.9

$ANACONDA_BINDIR/python2 setup.py install

cd $SCRIPTDIR


