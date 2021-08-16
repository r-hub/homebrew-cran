# Superseded

This project is superseded by the autobrew organization on GitHub: https://github.com/autobrew

---


# Old content

[![Build Status](https://travis-ci.org/r-hub/homebrew-cran.svg?branch=master)](https://travis-ci.org/r-hub/homebrew-cran)
![beta](https://img.shields.io/badge/status-beta-orange.svg)


A system for building statically linked R binary packages for MacOS based on homebrew.
The resulting package can be installed on any MacOS without the need for a compiler or
any external libraries, just like the one from CRAN.

## Prerequisites

Use the official [R for OSX](https://cran.r-project.org/bin/macosx/) from CRAN. 
This is the only build that supports CRAN binary packages. You can either run the
installer GUI or use homebrew to install it:

```
brew cask install r-app
```

Do **not install the Homebrew version of R**. We only use Homebrew for external
libraries.

You also need the xcode CLT (command line tools). Usually these were installed
automatically when you installed homebrew. Run this code to verify:

```
xcode-select --install
```

### Optional: Fortran / OpenMP

If you want to build packages that contain **fortran code** you should also install 
the official [GFortran Binaries](https://gcc.gnu.org/wiki/GFortranBinaries#MacOS).
Either walk through the installer or run:

```
brew cask install gfortran
```

The gfortran runtime libs are included with the official R for OSX installation.

Finally CRAN provides a [custom build of clang4](https://cran.r-project.org/bin/macosx/tools/)
with OpenMP support. Install this **if and only if you need OpenMP**. If you don't
know the answer to this question, please stick with the standard compilers from xcode.

## How to use

If you already have an homebrew installation you can just do:

```
brew tap r-hub/cran
brew install autobrew
```

Run the `autobrew` program on a tarball or package source directory:

```
autobrew ~/Downloads/RMySQL_0.10.13.tar.gz
```

Add a `--check` to run __R CMD check__ on the installation to ensure that it works before packaging it up:

```
autobrew --check ~/Downloads/RMySQL_0.10.13.tar.gz
``` 

Add `--download` to autobrew a CRAN package:

```
autobrew --download RMySQL
```

Add `--no-sysreq` to skip automatic installation of homebrew packages:

```
autobrew --no-sysreq RMySQL_0.10.13.tar.gz
```

Add `--repo=dirname` to specify where to save binary packages (default is current dir):

```
autobrew RMySQL_0.10.13.tar.gz --repo=binaries/3.4
```

Upon success the binary package `package_x.y.tgz` will created.
It also prints the runtime dependencies so you can verify that it does not link
to any local dynamic libraries, for example:

```
...
*** installing help indices
** building package indices
** testing if installed package can be loaded
* DONE (RMySQL)
Runtime dependencies for RMySQL/libs/RMySQL.so:
	RMySQL.so
	/usr/lib/libz.1.dylib
	/usr/lib/libiconv.2.dylib
	/usr/lib/libSystem.B.dylib
	/Library/Frameworks/R.framework/Versions/3.4/Resources/lib/libR.dylib
	/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation
Check that there are no links to /usr/local/ above!
Restoring dynamic libraries.
Success! Created binary package: RMySQL_0.10.13.tgz
```

## Instructions for package authors

The R package configure script should query `pkg-config` for the appropriate 
`--cflags` and `--libs` just like on any other system. Most R packages do this 
already, either directly or via autoconf. Autobrew automatically tags on the
`--static` flag to all calls to `pkg-config`.

Moreover packages should declare system dependencies in the `SysRequirements` field
in the `DESCRIPTION` file. The [r-hub sysreqdb](https://sysreqs.r-hub.io/) is used to 
resolve `SysRequirements` strings into proper system libraries, which map into the
respective homebrew package. The [mysql-client](https://github.com/r-hub/sysreqsdb/blob/master/sysreqs/mysql-client.json)
entry is a good example.

If your package has a system requirement which has not yet been registered in our
sysreqdb, please [open a pull request on GitHub](https://github.com/r-hub/sysreqsdb).


### Bootstrapper

TODO: bootstrap script to run on machines that do not have homebrew installed.

## Under the hood

The `autobrew` script performs these steps:

 1. Calls R-hub [sysreqdb](https://sysreqs.r-hub.io/) API to lookup system dependencies from the package `SysRequirements` field.
 2. For each brew pkg run `brew install $pkg` unless a custom install script exists in the `Hacks` directory.
 3. Then it compiles the R package __*while temporarily hiding homebrew dynamic libraries from the linker path*__. Thereby the linker can only use static libraries.
 4. Upon success: tar up the binary folder, print dependency summary, and restore dynamic libraries.

More detailed explanations of the process are below.

### Custom configurations

Homebrew is really nice and the majority of upstream C/C++ libraries work out of the 
box. However some libraries need a little extra love.
For these libraries have custom install scripts in the [Hacks](Hacks) folder of
this repository.

For example, for some libraries we need a non-standard configuration 
(`--with-foo --without-bar --enable-static`) or work around limitations/bugs.
A common problem is that the package `.pc` file has not properly recorded all
dependencies for static linking. We really try to keep this to a minimum and 
get problems fixed upstream, [either in homebrew](https://github.com/Homebrew/homebrew-core/commits?author=jeroen) 
or the C/C++ libtrary itself.

Also some packages need to bundle additional configuration files, executables or 
other files to make things work. This can be done in autobrew by copying these files
into `${PKG_EXTRA}` in install script. See the [Hacks](Hacks) for [gpgme](Hacks/gpgme)
or [imagemagick](Hacks/imagemagick) for examples.

### How we force static linking

To enforce static linking of local libararies, we need to hide the dynamic libraries 
during the linking step. The xcode linker by default checks in `/usr/local/lib` and
`/usr/lib` as we can see from this output:

```sh
clang -Xlinker -v
# Library search paths:
# 	/usr/lib
# 	/usr/local/lib
# Framework search paths:
# 	/Library/Frameworks/
# 	/System/Library/Frameworks/
```

Therefore before building the R package, we rename all of the `.dylib` files in these directories
to another file extension. Thereby the linker will only be able to find static libraries (`.a` files)
and link against these.

However here is the tricky part: MacOS may still need some of these dynamic libraries to 
run the R itself or the package `configure` script. But they no longer exist in the default
libraries. Therfore we put a temporary copy or symlink of the "hidden" dylibs in a location
where MacOS can find them (but not the the linker).

On MacOS < 10.11 we would use `DYLD_FALLBACK_LIBRARY_PATH` which does exactly this.
Unfortunately as of MacOS 10.11 the use of `DYLD_FALLBACK_LIBRARY_PATH` by scripts has been
disabled for security reasons as part of the new "System Integrity Protection". It
is possible to disable SIP but it requires root and a reboot.

Therefore we rely on an alternative method which is to copy the dynamic libraries into 
the user home directory under `~/lib`. This location is also on the default search path
for dynamic libraries, but not used by the linker. In most cases this will ensure that
R and everything else still works while the dynamic libraries are hidden.

## Important Notes

### OS-X Compatibility

Binary R packages built on a given version of MacOS can be installed on that same version
or more recent versions of MacOS. The binary packages is not guaranteed to work on older
versions of MacOS. This is mainly an issue when the package uses system libraries that 
take advantage of recently introduced MacOS features.

Therefore to build binaries that work for most MacOS systems, it is safer to target
a somewhat older version of MacOS. However note that homebrew only supports the 3 most
recent versions of MacOS, e.g. version 10.11, 10.12, and 12.13. Anything older is
effectively deprecated and not actively maintained.

Therefore the recommended MacOS target version for R binary packages is usually the latest
version minus 2, i.e. currently 10.11 (El Capitan) (which is also the [CRAN version](https://cran.r-project.org/bin/macosx/)).


### Compiler mixing

Static linking is very sensitive to ABI compatibility. Homebrew builds all libraries using
native xcode. Therefore they are only guaranteed to work well with R if we compile our R
packages also with xcode. Luckily this is the default.

CRAN uses a [custom build of clang4](http://r.research.att.com/libs/cran-usr-local-darwin15.6-20170320.tar.gz) 
that has support for OpenMP. Luckily this version seems to be compitible with homebrew/xcode
in almost all cases (though sometimes the headers can conflict).

R packages built with GCC or other compilers may not be compatible with homebrew. 

[1] https://cran.r-project.org/doc/manuals/R-admin.html#Unix_002dalike-standalone
