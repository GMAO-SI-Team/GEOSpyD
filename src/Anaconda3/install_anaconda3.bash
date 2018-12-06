#!/bin/bash

usage() {
   echo "Usage: $0 --python_version <python version> --anaconda_version <anaconda_version"
   echo "   Required arguments:"
   echo "      --python_version <python version> (e.g., 3.7)"
   echo "      --anaconda_version <anaconda version> (e.g., 5.3.1)"
   echo ""
   echo "   Optional arguments:"
   echo "      --help: Print this message"
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

# -----------------------------
# Set the Anaconda Architecture
# -----------------------------

if [[ $ARCH == Darwin ]]
then
   ANACONDA_ARCH=MacOSX
else
   ANACONDA_ARCH=Linux
fi

# --------------------------
# Anaconda version variables
# --------------------------

ANACONDA_DISTVER=Anaconda3

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

# -----------------------------------------------------------
# Location of the Anaconda2 sh installer -- System Dependent!
# -----------------------------------------------------------

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

case $SITE in
   NCCS)
      ANACONDA_DIR=/discover/swdev/mathomp4/anaconda
      ;;
   NAS)
      ANACONDA_DIR=/nobackup/gmao_SIteam/anaconda
      ;;
   GMAO.desktop)
      ANACONDA_DIR=/ford1/share/gmao_SIteam/anaconda
      ;;
   *)
      # Let's just install to home
      ANACONDA_DIR=$HOME/anaconda
      ;;
esac

ANACONDA_SRCDIR=$ANACONDA_DIR/src/$ANACONDA_DISTVER
DATE=$(date +%F)

ANACONDA_INSTALLDIR=$ANACONDA_DIR/$ANACONDA_VER/$PYTHON_VER/$DATE

INSTALLER=${ANACONDA_DISTVER}-${ANACONDA_VER}-${ANACONDA_ARCH}-${MACH}.sh

#echo "ANACONDA_SRCDIR     = $ANACONDA_SRCDIR"
echo "Anaconda will be installed in $ANACONDA_INSTALLDIR"
#echo "INSTALLER           = $INSTALLER"
#exit

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

$ANACONDA_BINDIR/conda install -y mpi4py netcdf4 cartopy cubes krb5 \
   pyasn1 redis redis-py ujson mdp configobj blaze argcomplete biopython \
   launcher sockjs-tornado sphinx_rtd_theme virtualenv django mock psycopg2 \
   requests-toolbelt twine wxpython

# Many packages on Anaconda have no macOS or noarch version
# ---------------------------------------------------------

if [[ $ANACONDA_ARCH == Linux ]]
then
   $ANACONDA_BINDIR/conda install -y util-linux
   # MAT wsgiref does not have a Python 3 package
   #$ANACONDA_BINDIR/conda install -y wsgiref
fi

# Install weird nc_time_axis package
# ----------------------------------

$ANACONDA_BINDIR/conda install -y -c conda-forge/label/renamed nc_time_axis

# Install conda-forge packages
# ----------------------------

$ANACONDA_BINDIR/conda install -y -c conda-forge iris pyhdf basemap \
   geotiff gdal f90wrap eofs joblib pyspharm windspharm mo_pack \
   libmo_unpack f90nml pygrib seawater biggus plotly theano matplotlib \
   tk xorg-kbproto xorg-libice xorg-libsm xorg-libx11 xorg-libxext \
   xorg-libxrender xorg-renderproto xorg-xextproto xorg-xproto xarray

# PyRTF3 is the Python3 version of PyRTF/rtfw. Install from pip
# -------------------------------------------------------------

$ANACONDA_BINDIR/python3 -m pip install PyRTF3 pipenv ffnet

# Finally pygrads is not even in pip
# ----------------------------------

####################################################################
# tar xf $ANACONDA_SRCDIR/pygrads-1.1.9.tar.gz -C $ANACONDA_SRCDIR #
#                                                                  #
# cd $ANACONDA_SRCDIR/pygrads-1.1.9                                #
#                                                                  #
# $ANACONDA_BINDIR/python2 setup.py install                        #
#                                                                  #
# cd $SCRIPTDIR                                                    #
####################################################################

# Inject Joe Stassi's f2py shell fix into numpy
# ---------------------------------------------
find $ANACONDA_INSTALLDIR/lib -name 'exec_command.py' -print0 | xargs -0 $SED -i -e 's#^\( *\)use_shell = False#&\n\1command.insert(1, "-f")#'


