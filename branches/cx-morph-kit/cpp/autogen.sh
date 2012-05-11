#! /bin/sh

set -x
libtoolize
aclocal -I m4
autoheader
automake --add-missing --copy
touch NEWS README AUTHORS ChangeLog
automake --add-missing
autoconf
autoscan

# autoreconf -fvi
