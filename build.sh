#!/bin/bash

set -e
set -x

THIS_DIR="$PWD"

# Should use same python version on host #
PYVER=3.13.11
SRCDIR=src/Python-$PYVER

COMMON_ARGS="--arch ${ARCH:-arm} --api ${ANDROID_API:-21}"

if [ ! -d $SRCDIR ]; then
    mkdir -p src
    pushd src
    curl -kvLO https://www.python.org/ftp/python/$PYVER/Python-$PYVER.tar.xz
    # Use --no-same-owner so that files extracted are still owned by the
    # running user in a rootless container
    tar --no-same-owner -xf Python-$PYVER.tar.xz
    popd
fi

cp -r Android $SRCDIR
pushd $SRCDIR
if patch --forward -Np1 -i ./Android/unversioned-libpython.patch; then
    autoreconf -ifv
fi

# Build a native Python of the same version to use as build-python for
# cross-compilation, avoiding version mismatch issues with PYTHONPATH
NATIVE_PYTHON="$THIS_DIR/native_python"
if [ ! -x "$NATIVE_PYTHON/bin/python3" ]; then
    mkdir -p "$THIS_DIR/native_build"
    pushd "$THIS_DIR/native_build"
    "$THIS_DIR/$SRCDIR/configure" \
        --prefix="$NATIVE_PYTHON" \
        --disable-test-modules \
        --with-ensurepip=no
    make -j
    make install
    popd
fi

./Android/build_deps.py $COMMON_ARGS
./Android/configure.py $COMMON_ARGS --with-build-python="$NATIVE_PYTHON/bin/python3" --enable-shared --prefix=/usr "$@"
CFLAGS="-w" make -j
make install DESTDIR="$THIS_DIR/build"
popd

BUILDDIR="$THIS_DIR/build"
PYSHORTVER="${PYVER%.*}"

PYLIB="$BUILDDIR/usr/lib/python$PYSHORTVER"

# Remove modules and files not needed at runtime on Android
rm -rf "$PYLIB/test"           # test suite
rm -rf "$PYLIB/idlelib"        # GUI editor
rm -rf "$PYLIB/tkinter"        # GUI toolkit (no display on Android)
rm -rf "$PYLIB/turtledemo"     # graphics demo
rm -rf "$PYLIB/unittest"       # unit testing framework
rm -rf "$PYLIB/ensurepip"      # pip installer (pip already installed)
rm -rf "$PYLIB/venv"           # virtual environment creation
rm -rf "$PYLIB/config-$PYSHORTVER-"*  # build-time config (linking only)
rm -f  "$PYLIB/turtle.py"      # graphics
rm -f  "$PYLIB/doctest.py"     # docstring testing
rm -f  "$BUILDDIR/usr/lib/libpython$PYSHORTVER.a"  # static library
# Remove accidental path created by ensurepip during cross-compilation
rm -rf "$BUILDDIR/home"

# Remove .opt-*.pyc files (only used with -O/-OO flags, not needed by default)
find "$BUILDDIR" -name "*.opt-*.pyc" -delete
# Remove orphaned __pycache__ entries for any .py files we deleted above
find "$BUILDDIR" -path "*/__pycache__/*.pyc" | while read pyc; do
    src="${pyc%/__pycache__/*}/$(basename "$pyc" | sed 's/\.cpython-[0-9]*\.pyc$/.py/')"
    [ -f "$src" ] || rm -f "$pyc"
done
find "$BUILDDIR" -type d -name "__pycache__" -empty -delete

# Strip debug symbols from ELF binaries using NDK llvm-strip
NDK_STRIP=$(ls "${ANDROID_NDK}"/toolchains/llvm/prebuilt/*/bin/llvm-strip 2>/dev/null | head -1)
if [ -n "$NDK_STRIP" ]; then
    find "$BUILDDIR/usr/bin" -type f \
        -exec "$NDK_STRIP" --strip-unneeded {} \; 2>/dev/null || true
    find "$BUILDDIR/usr/lib" -name "*.so" \
        -exec "$NDK_STRIP" --strip-unneeded {} \; 2>/dev/null || true
fi

cp -r $SRCDIR/Android/sysroot/usr/share/terminfo build/usr/share/
cp devscripts/env.sh build/
