In order to use the install script do (for example):

```
./install_miniconda.bash --python_version 3.11 --miniconda_version 23.5.2-0 --prefix /opt/GEOSpyD
```

will create an install at:
```
/opt/GEOSpyD/23.5.2-0_py3.11/YYYY-MM-DD
```

where YYYY-MM-DD is the date of the install. We use a date so that if
the stack is re-installed, the previous install is not overwritten.
