#!/bin/bash
set -e
AUTOBREW_ROOT=$(dirname $(greadlink -f "${BASH_SOURCE[0]}"))
AUTOBREW_REPO="${PWD}/binaries"

# Some global settings
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ANALYTICS=1

# Print --help and exit
print_help () {
	echo "Example usage:"
	echo "  $(basename $0) mypkg_1.2.tar.gz"
	echo "  $(basename $0) /some/directory/mypkg"
	echo "  $(basename $0) magick --download  (autobrew cran package)"
	echo ""
	echo "Additional options:"
	echo "  $(basename $0) mypkg_1.2.tar.gz --check   (run CMD check)"
	echo "  $(basename $0) mypkg_1.2.tar.gz --no-sysreq"
	echo "  $(basename $0) mypkg_1.2.tar.gz --repo=binaries/3.4"
	exit 1
}

prepare_homebrew(){
	# Check if brew exists
	brew --version 2>/dev/null

	# Install Homebrew if not installed yet
	if [ $? -eq 0 ]; then
		BREWDIR=$(brew --prefix)
		BREW="${BREWDIR}/bin/brew"
		DYNLIB_DIR="${BREWDIR}/lib/dynlib"
		mkdir -p "${DYNLIB_DIR}"
	else
		echo "Unable to find homebrew installation"
		exit 1
	fi
}

cran_tap(){
	local TAPDIR=$($BREW --repo r-hub/cran)
	if [ -d ${TAPDIR} ]; then
		echo "CRAN tap OK"
	else
		$BREW tap r-hub/cran
	fi
}

for arg in "$@"; do
case $arg in
	--help)
	print_help
	exit 0;;
	--test)
	ARGS=$(echo "$@" | sed 's/--test//')
	${AUTOBREW_ROOT}/tests.sh ${ARGS}
	exit 0;;
	--check)
	export AUTOBREW_CHECK="TRUE";;	
	--download)
	AUTOBREW_DOWNLOAD="TRUE";;	
	--debug)
	AUTOBREW_DEBUG="TRUE";;
	--no-sysreq)
	AUTOBREW_NOSYSREQ="TRUE";;
	--install-args=*)
	EXTRA_BUILD_FLAGS="${arg#*=}";;
	--repo=*)
	AUTOBREW_REPO="${arg#*=}";;
	--*)
	echo "Unsupported argument: $arg"
	exit 1;;
	*)
	SCRIPT_ARG=$arg
esac
done

# Get full path to output dir
mkdir -p ${AUTOBREW_REPO}
AUTOBREW_REPO=$(greadlink -f "${AUTOBREW_REPO}")

# Setup build dirs
PKG_BUILD="_AUTOBREW_BUILD"
rm -Rf ${PKG_BUILD}
mkdir -p ${PKG_BUILD}

if [[ ${AUTOBREW_DOWNLOAD} && ${SCRIPT_ARG} ]]; then
	SCRIPT_ARG=$(Rscript --vanilla ${AUTOBREW_ROOT}/download.R "${SCRIPT_ARG}")
fi

if [ -f "$SCRIPT_ARG" ]; then
	tar xzvf $SCRIPT_ARG -C ${PKG_BUILD} --strip=1 '*/DESCRIPTION$' 
	export PKG_TARBALL=$SCRIPT_ARG
elif [ -d "$SCRIPT_ARG" ]; then
	R CMD build $SCRIPT_ARG --no-build-vignettes #don't have dependencies yet
	cp -f $SCRIPT_ARG/DESCRIPTION ${PKG_BUILD}/
else 
	print_help
fi

# Extract some fields
PKG_NAME=$(Rscript --vanilla -e "cat(read.dcf('${PKG_BUILD}/DESCRIPTION')[[1,'Package']])")
PKG_VERSION=$(Rscript --vanilla -e "cat(read.dcf('${PKG_BUILD}/DESCRIPTION')[[1,'Version']])")
PKG_TARBALL=${PKG_TARBALL-${PKG_NAME}_${PKG_VERSION}.tar.gz}

# Setup homebrew installation
prepare_homebrew

# Dir for extra files
PKG_EXTRA="${PKG_BUILD}/EXTRA"
mkdir -p ${PKG_EXTRA}

# Resolve brew dependencies
if [ -z "$AUTOBREW_NOSYSREQ" ]; then
	cran_tap
	Rscript --vanilla ${AUTOBREW_ROOT}/dependencies.R "${PKG_BUILD}/DESCRIPTION"
	TAPDIR=$(${BREW} --repo r-hub/cran)
	PKG_DEPS=$(<${PKG_BUILD}/PKG_DEPS)
	if [ "$PKG_DEPS" ]; then
		echo "Found brew dependencie(s): $PKG_DEPS"
		for PKG in $PKG_DEPS; do
			if [ -f "${TAPDIR}/altinst/${PKG}" ]; then
				PKG=$(<${TAPDIR}/altinst/${PKG})
			fi
			PKG_DEPS=$(${BREW} deps -n ${PKG})
			${BREW} ls ${PKG} --versions || ${BREW} install ${PKG_DEPS} ${PKG}
			if [ -f "${TAPDIR}/postinst/${PKG}" ]; then
				source "${TAPDIR}/postinst/${PKG}" || true
			fi
		done
	else
		echo "No brew dependencies found for this package"
	fi
fi

# Move dynlibs out of linker path

# Temporarily rename global dynlibs
function on_exit {
  echo "Restoring dynamic libraries."
  rename 's/\.dylib-bak$/\.dylib/' $(find ${BREWDIR}/Cellar/*/*/lib -name *.dylib-bak) >/dev/null 2>&1
  rm -f "${HOME}/lib"
  if [ -z "$AUTOBREW_DEBUG" ]; then
    rm -Rf ${PKG_BUILD}
  fi
  if [ -f "$PKG_BINARY" ]; then
  	echo "Success! Created binary package: $PKG_BINARY"
  else
  	echo "Something went wrong :("
  	exit 1
  fi
}

# Copy (or hardlink) all dylibs to special dir (not the symlinks)
DYNLIB_FILES=$(find ${BREWDIR}/Cellar/*/*/lib -name *.dylib -type f)
ln -f ${DYNLIB_FILES} ${DYNLIB_DIR}
ln -sf "${DYNLIB_DIR}" "${HOME}/lib"

# Hide dylibs out from linker path
trap on_exit EXIT
rename 's/\.dylib$/\.dylib-bak/' ${DYNLIB_FILES} >/dev/null 2>&1

# Mask pkg-config with our wrapper
export BREWDIR 
export PATH="${AUTOBREW_ROOT}/bin:${BREWDIR}/bin:$PATH"
export DYLD_FALLBACK_LIBRARY_PATH="${DYNLIB_DIR}"
export FC="/usr/local/bin/gfortran"

# Set to disable linking against XQuartz libs
if [ -z "NO_XQUARTZ" ]; then
export PKG_CONFIG_PATH="/usr/lib/pkgconfig:$BREWDIR/lib/pkgconfig:/opt/X11/lib/pkgconfig"
fi

# Copy extra files
if [ "$(ls -A ${PKG_EXTRA})" ]; then
	TARBALL_PATH=$(greadlink -f ${PKG_TARBALL})
	cd ${PKG_BUILD}
	rm -Rf ${PKG_NAME}
	tar xzf ${TARBALL_PATH}
	mkdir -p ${PKG_NAME}/inst
	echo "Copying extra files:"
	cp -Rvf EXTRA/* ${PKG_NAME}/inst/
	find EXTRA -type f | sed 's#EXTRA#inst#' > ${PKG_NAME}/BinaryFiles
	rm -f ${PKG_TARBALL}
	GZIP=-9 tar -czf ${TARBALL_PATH} ${PKG_NAME}
	rm -Rf ${PKG_NAME}
	cd ..
fi

# Build the binary package
export _R_CHECK_FORCE_SUGGESTS_=0
INSTALL_ARGS="--build ${EXTRA_BUILD_FLAGS}"
if [ "$AUTOBREW_CHECK" ]; then
R CMD check --library="${PKG_BUILD}" --install-args="${INSTALL_ARGS}" --no-manual --no-build-vignettes ${PKG_TARBALL}
else
R CMD INSTALL --library="${PKG_BUILD}" ${INSTALL_ARGS} ${PKG_TARBALL}
fi

# Move binary package to repo and update PACKAGES index
mv "${PKG_NAME}_${PKG_VERSION}.tgz" "${AUTOBREW_REPO}/"
PKG_BINARY="${AUTOBREW_REPO}/${PKG_NAME}_${PKG_VERSION}.tgz"
Rscript --vanilla -e "tools::write_PACKAGES(dir='${AUTOBREW_REPO}', type='mac.binary', verbose = TRUE)"

# Print linekd libs
cd ${PKG_BUILD}
if [ -f "${PKG_NAME}/libs/${PKG_NAME}.so" ]; then
	printf "Runtime dependencies for "
	otool -L ${PKG_NAME}/libs/*.so | sed 's/(compatibility.*//g' || true
	echo "Check that there are no links to /usr/local/ above!"
else
	echo "Package has no compiled code."
fi
cd ..
