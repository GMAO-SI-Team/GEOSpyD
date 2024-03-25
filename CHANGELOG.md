# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

### Changed

- Updated to miniconda 24.1.2-0
- Updated to Python 3.12 by default
- Use micromamba by default on Linux
- Add BLIS as allowed BLAS
- Added ability for ffnet to install on macOS
  - The script looks for a gfortran compiler and if it finds one, it will install ffnet

### Added

- Explicit Conda Packages
  - haversine
  - ford
  - autopep8
  - mdutils
  - f90wrap (moved from pip)
- Explicit Pip Packages
  - wordcloud (moved from conda)
  - meson (required for ffnet)

### Removed

- Explicit Conda Packages
  - wordcloud (moved to pip)
- Explicit Pip Packages
  - theano (no longer maintained)
  - blaze (no longer maintained)
  - f90wrap (moved to conda)

### Deprecated

## [23.5.2] - 2023-10-17

### Fixed

- Fixed possible pygrads install issue
- Fixed odd libcxx issue between miniconda and conda-forge
- Fixed issue with gfortran version detection

### Added

- Added micromamba support
  - micromamba is a new, experimental, lightweight conda installer; we use it by default on macOS
  - mamba is still default on Linux

- Explicit Conda Packages
  - scikit-learn
  - yamllint
  - verboselogs
  - libblas
    - Defaults to using `accelerate` on Arm-based macOS, and `mkl` on Intel-based macOS and Linux
  - movingpandas
  - geoviews
  - hvplot (pinned to 0.8.3)
  - bokeh (pinned to 3.1)
  - geopandas
  - intake
  - intake-parquet
  - intake-xarray
  - pykdtree
  - pyogrio
  - contourpy
  - sunpy

- Explicit Pip Packages
  - lxml
  - juliandate

- Added example for ffnet
- Added changelog enforcer

### Changed

- Removed `src/` directory as unnecessary; all files are now in the root
- Updated example miniconda version to 23.5.2-0
- Updated example Python version to 3.11
- Explicit Pip Packages
  - ffnet
    - Moved to use a Git master branch of the package to fix issues with Python3 and scipy
    - Requires gfortran 8.3 or higher
- Updated readmes with latest versions

### Removed

- Explicit Conda Packages
  - basemap (obsolete, use cartopy)
  - cubes (caused downgrade to Python 3.9)
  - gooey (caused downgrade of many packages)
  - mdp (obsolete, not supported by 3.11)

## [4.11.0] - 2022-04-28

### Added

- Explicit Conda Packages
  - wordcloud
  - zarr

- Explicit Pip Packages
  - ruamel.yaml
  - tensorflow
  - evidential-deep-learning
  - yaplon

### Changed

- Only install `pythran` on Linux
- Instead of removing the `mpi*` files in `bin`, we now rename to `esmf-mpi*`
- Moved `xgboost` from mamba install to pip (due to pip having the latest version)

### Removed

- Removed the anaconda install scripts
- Removed support for Python 2

## [4.10.3] - 2022-01-13

### Changed

- Made `mamba` the default installer. If you want to use `conda`, pass in `--conda` flag
- ffnet is only installed on Linux

### Added

- Explicit Conda Packages
  - cython
  - gsw
  - pythran
- Other Python Packages
  - PyGrADS 3
- Added `.editorconfig` file

## [4.9.2] - 2021-05-04

### Changed

- Added support for the `mamba` installer. This is now *recommended* for installs. Use `--mamba` to use

### Deprecated

- Miniconda no longer supports Python 2. From here on out all additions are for Python 3 only

### Added

- Explicit Conda Packages
  - boto3
  - questionary
  - s3fs
  - timezonefinder
  - xgrads

### Removed

- Removed numpy/intel injection

## [4.8.3] - 2020-08-31

### Changed

- Moved to use Miniconda installers instead of Anaconda
  - This is mainly done due to Anaconda no longer being able to satisfy the package requirement graph
  - This also means more packages are in now *explicitly* installed with conda as we now need to install them specifically (they
    came from Anaconda before)

### Added

- Explicit Conda Packages
  - astropy
  - babel
  - beautifulsoup4
  - colorama
  - esmpy
  - fastcache
  - get_terminal_size
  - gmp
  - greenlet
  - imageio
  - intel-openmp
  - jbig
  - jupyter
  - jupyterlab
  - lzo
  - mkl
  - mkl-service
  - mkl_fft
  - mkl_random
  - numba
  - numpy
  - pipenv (moved from pip)
  - proj4<6 (Python 2)
  - proj (Python 3)
  - pydap
  - pygrib
  - pypng
  - pytables
  - pytest
  - seaborn
  - scipy
  - sphinxcontrib
  - tbb
  - tbb4py
  - xesmf
  - xgcm

- Explicit Pip Packages
  - blaze
  - h5py
  - metpy (Python 3 only)
  - pycircleci (Python 3 only)
  - siphon (Python 3 only)
  - theano

### Removed

- Explicit Conda Packages
  - theano (moved to pip)
  - blaze (moved to pip)

## [2019.10] - 2020-01-15

### Added

- Explicit Conda Packages
  - gooey
  - hpccm
  - rasterio
- Explicit Pip Packages
  - f90wrap
  - pymp-pypi

### Removed

- Explicit Conda Packages
  - cis
  - django
  - f90wrap (moved to pip)
  - joblib
  - launcher
  - mock
  - psycopg2
  - pygrib
  - util-linux
  - xorg-libsm

### Changed

- Moved some conda packages to an earlier `conda install` command to satisfy dependency chain

## [2019.03] - 2019-05-08

### Added

- Initial release
  - Note: All listed packages are only those *expressly* asked for with a `conda install`. Some "basic" packages are from Anaconda,
    while conda will of course install other dependencies as well. For example, numpy is not in this list, but is part of GEOSpyD
- Explicit Conda Packages
  - argcomplete
  - basemap
  - biggus
  - biopython
  - blaze
  - cartopy
  - cdsapi
  - cmocean
  - cis
  - configargparse
  - configobj
  - cubes
  - django
  - eofs
  - f90nml
  - f90wrap
  - gdal
  - geotiff
  - iris
  - joblib
  - krb5
  - launcher
  - libmo_unpack
  - matplotlib
  - mdp
  - mock
  - mo_pack
  - nc_time_axis
  - netcdf4
  - pip
  - plotly
  - psycopg2
  - pyasn1
  - pygrib
  - pyhdf
  - pyspharm
  - redis
  - redis-py
  - requests-toolbelt
  - seawater
  - sockjs-tornado
  - sphinx_rtd_theme
  - theano
  - tk
  - twine
  - ujson
  - util-linux (Linux only)
  - virtualenv
  - wxpython
  - wsgiref (Python 2 only)
  - windspharm
  - xarray
  - xgboost
  - xorg-kbproto
  - xorg-libice
  - xorg-libsm
  - xorg-libx11
  - xorg-libxext
  - xorg-libxrender
  - xorg-renderproto
  - xorg-xextproto
  - xorg-xproto
- Explicit Pip Packages
  - ffnet
  - pipenv
  - PyRTF3 (Python 3)
  - rtfw (Python 2)
- Other Python Packages
  - PyGrADS (Python 2)
- Code injections
  - Fix for f2py and numpy
  - Fix for numpy and Intel
  - Make TkAgg the default matplotlib backend as that is the only one supported on all systems tested
