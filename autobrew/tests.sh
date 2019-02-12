#!/bin/sh
set -e

# Test homebrew rust compiler (doesn't work)
# autobrew --download gifski "$@"

# Using the gdal/geos/proj stack
autobrew --download sf "$@"
autobrew --download rgdal "$@"

# Using the video stack
autobrew --download av "$@"

# Test BioConductor pkg with some deps
autobrew --download IRanges "$@"

# Some usual suspects
autobrew --download odbc "$@"
autobrew --download xml2 "$@"
autobrew --download RMariaDB "$@"
autobrew --download png "$@"
autobrew --download webp "$@"
autobrew --download rsvg "$@"
autobrew --download magick "$@"
autobrew --download RMySQL "$@"
autobrew --download openssl "$@"
autobrew --download sodium "$@"
autobrew --download curl "$@"
autobrew --download RProtoBuf "$@"
autobrew --download pdftools "$@"
autobrew --download V8 "$@"
autobrew --download redland "$@"
autobrew --download gmp "$@"

# Ship extra files (tessdata)
autobrew --download tesseract "$@"

# Tests configure executable (protoc)
autobrew --download protolite "$@"

# Tests onload executable (gpg)
autobrew --download gpg "$@"

# Test NetCDF static linking
autobrew --download RNetCDF "$@"

# Test without any compiled code
autobrew --download magrittr "$@"

# Test Fortran
autobrew --download glmnet "$@"

# Tests everything together (fortran, gmp, xml2)
autobrew --download igraph "$@"

# All done!
echo "GREAT SUCCESS!"
