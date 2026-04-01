Python 3 Android
================

Build scripts that cross-compile Python 3 for Android devices.

Currently targeting **Python 3.13.11**.

Prerequisites
-------------

Building requires:

1. Linux (other platforms supported by NDK may work but are not tested)
2. Android NDK r19 or above. Set `$ANDROID_NDK` to its root directory.
   Tested with NDK r26.2 (`26.2.11394342`).
3. `tic` binary from ncurses on the building host (for terminfo generation)
4. A case-sensitive filesystem. The default filesystem on Windows and macOS is
   case-insensitive and building may fail.
5. `curl`, `patch`, `make`, `gcc` on the building host

> **Note:** A matching-version Python on the host is **not** required.
> The build script automatically compiles a native Python of the same version
> from source and uses it as the cross-compilation build-python.

Running requires:

1. Android 5.0 (Lollipop, API 21) or above
2. Architecture: `arm`, `arm64`, `x86`, or `x86_64`

Build
-----

```sh
./clean.sh
ARCH=arm64 ANDROID_API=21 ANDROID_NDK=/path/to/ndk ./build.sh
```

Supported `ARCH` values: `arm`, `arm64`, `x86`, `x86_64`

The build proceeds in the following steps:

1. Download Python source if not already present in `src/`
2. Copy the `Android/` build scripts into the source tree
3. Apply `unversioned-libpython.patch` if needed (skipped on Python 3.13+
   which already includes the fix)
4. Build a **native** Python of the same version into `native_python/`
   (reused on subsequent builds if already present)
5. Build Android dependencies (bzip2, gdbm, libffi, libuuid, ncurses,
   openssl, readline, sqlite, xz, zlib) into `Android/sysroot/`
6. Configure and build Python for Android
7. Install into `build/`
8. Remove files not needed at runtime: `test/`, `idlelib/`, `config-*/`,
   `libpython*.a`, and the accidental ensurepip path
9. Strip debug symbols from ELF binaries and `.so` files using NDK `llvm-strip`

Output is placed in `build/`. A typical build produces ~80 MB after cleanup
and stripping (down from ~370 MB before).

Build using Docker/Podman
--------------------------

Download the latest NDK for Linux from https://developer.android.com/ndk/downloads
and extract it.

```sh
docker run --rm -it \
  -v $(pwd):/python3-android \
  -v /path/to/android-ndk:/android-ndk:ro \
  --env ARCH=arm64 \
  --env ANDROID_API=21 \
  python:3.13-slim \
  /python3-android/docker-build.sh
```

Podman is also supported. Simply replace `docker` with `podman`.

Installation
------------

1. Make sure `adb shell` works
2. Copy all files in `build/` to a folder on the device (e.g., `/data/local/tmp/python3`).
   Note that `/sdcard` is not a POSIX-compliant filesystem; the Python binary will not run from there.
3. In `adb shell`:

```sh
cd /data/local/tmp/python3
. ./env.sh
python3
```

SSL/TLS
-------

Android uses the old certificate naming scheme while OpenSSL uses the new one.
If you get `CERTIFICATE_VERIFY_FAILED`, collect system certificates:

```sh
cd /data/local/tmp/python3
mkdir -p etc/ssl
cat /system/etc/security/cacerts/* > etc/ssl/cert.pem
```

The certificate path may vary by device vendor and Android version. Root access
is required to collect user-installed certificates.

Verify SSL/TLS:

```python
import urllib.request
print(urllib.request.urlopen('https://httpbin.org/ip').read().decode('ascii'))
```

Cleaning
--------

```sh
./clean.sh
```

This removes `src/`, `build/`, `native_build/`, and `native_python/`.
To preserve the native Python build across clean cycles (saves significant
build time), remove `native_build` and `native_python` from `clean.sh`.

Known Issues
------------

- Python 3.13.11 cannot be cross-compiled using a host Python 3.13.0 binary
  due to an internal API change in `linecache._register_code` between those
  versions. The build script works around this by building a native
  Python 3.13.11 from source automatically.
- The `unversioned-libpython.patch` is a no-op on Python 3.13+ (the fix is
  already included upstream). The build script skips it gracefully.
