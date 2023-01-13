# get NDK from android source #
cd android/prebuilts/cmdline-tools/tools/bin
./sdkmanager --list
./sdkmanager --install "ndk;21.4.7075529"

# Should use same python version for for build on host #

# build python for android #
sudo apt install -y libtool autoconf-archive;
./clean.sh;
ARCH=arm64 ANDROID_API=29 ANDROID_NDK=/home/iipeace/android/prebuilts/ndk/21.4.7075529 ./build.sh
