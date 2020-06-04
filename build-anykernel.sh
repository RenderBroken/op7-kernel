#!/bin/bash

#
#  Build Script for RenderZenith!
#  Based off AK's build script - Thanks!
#

# Bash Color
rm .version
green='\033[01;32m'
red='\033[01;31m'
blink_red='\033[05;31m'
restore='\033[0m'

clear

# Resources
THREAD="-j$(grep -c ^processor /proc/cpuinfo)"
KERNEL="Image.gz"
export DEFCONFIG="oneplus7_defconfig"

# Kernel Details
VER=RenderZenith
DEVICE=OP7PRO
VARIANT="OP7-OOS-Q"

# Kernel zip name
HASH=`git rev-parse --short=8 HEAD`
KERNEL_ZIP="RZ-$VARIANT-$(date +%y%m%d)-$HASH" 

# Enable ccache per device
CCACHE=ccache
export CCACHE_DIR="$HOME/.ccache/kernel/$DEVICE"

# Vars
export LOCALVERSION=~`echo $VER`
export ARCH=arm64
export SUBARCH=arm64 
export KBUILD_BUILD_USER=RenderBroken
export KBUILD_BUILD_HOST=RenderZenith
export LOCALVERSION=~`echo $KERNEL_ZIP`

# Extra make arguments
EXTRA_CONFIGS="CONFIG_BUILD_ARM64_DT_OVERLAY=y CONFIG_BUILD_ARM64_KERNEL_COMPRESSION_GZIP=y CONFIG_DEBUG_SECTION_MISMATCH=y"

# Paths
KERNEL_DIR=`pwd`
KBUILD_OUTPUT="${KERNEL_DIR}/../out_$DEVICE"
REPACK_DIR="${HOME}/android/source/kernel/AnyKernel3"
PATCH_DIR="${HOME}/android/source/kernel/AnyKernel3/patch"
MODULES_DIR="${HOME}/android/source/kernel/AnyKernel3/modules"
ZIP_MOVE="${HOME}/android/source/zips/OP7-zips"
ZIMAGE_DIR="$KBUILD_OUTPUT/arch/arm64/boot"

# Create output directory
mkdir -p $KBUILD_OUTPUT 

# Functions
function checkout_ak3_branches {
        cd $REPACK_DIR
        git checkout rz-op7-oos-q
        cd $KERNEL_DIR
}

function clean_all {
        rm -rf $REPACK_DIR/$MODULES_DIR/*
        rm -f $REPACK_DIR/$KERNEL
        rm -f $REPACK_DIR/zImage
        rm -f $REPACK_DIR/dtb
        echo
        make O=$KBUILD_OUTPUT clean && make O=$KBUILD_OUTPUT mrproper
}

function make_clang_kernel {
	export CROSS_COMPILE=${HOME}/android/source/toolchains/aarch64-linux-android-4.9/bin/aarch64-linux-android-
	REAL_CC="${HOME}/android/source/toolchains/clang-linux-x86/clang-r370808/bin/clang"
	CLANG_TRIPLE="aarch64-linux-gnu-"

	echo
	make $DEFCONFIG O=$KBUILD_OUTPUT $EXTRA_CONFIGS

    echo
    echo "Building with Clang..."
    echo

	make -s $THREAD \
		ARCH=$ARCH \
		REAL_CC="$CCACHE $REAL_CC" \
		CLANG_TRIPLE=$CLANG_TRIPLE \
		CROSS_COMPILE="$CROSS_COMPILE" \
		O=$KBUILD_OUTPUT \
		$EXTRA_CONFIGS
}

function make_gcc_kernel {
	export CROSS_COMPILE="${CCACHE} ${HOME}/android/source/toolchains/gcc-linaro-6.5.0-2018.12-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-"

    echo
    echo "Building with GCC..."
    echo

	make O=${KBUILD_OUTPUT} $DEFCONFIG
	make -s O=${KBUILD_OUTPUT} $THREAD
}

function make_modules {
	# Remove and re-create modules directory
	rm -rf $MODULES_DIR
	mkdir -p $MODULES_DIR

	# Copy modules over
	echo
        find $KBUILD_OUTPUT -name '*.ko' -exec cp -v {} $MODULES_DIR \;

	# Strip modules
	${CROSS_COMPILE}strip --strip-unneeded $MODULES_DIR/*.ko

    # Sign modules
    if grep -Fxq "CONFIG_MODULE_SIG=y" $KBUILD_OUTPUT/.config
    then
        find $MODULES_DIR -name '*.ko' -exec $KBUILD_OUTPUT/scripts/sign-file sha512 $KBUILD_OUTPUT/certs/signing_key.pem $KBUILD_OUTPUT/certs/signing_key.x509 {} \;
    fi 
}

function make_zip {
	cp -vr $ZIMAGE_DIR/$KERNEL $REPACK_DIR/$KERNEL
	find $KBUILD_OUTPUT/arch/arm64/boot/dts -name '*.dtb' -exec cat {} + > $REPACK_DIR/dtb
	cd $REPACK_DIR
	zip -r9 $KERNEL_ZIP.zip *
	mv $KERNEL_ZIP.zip $ZIP_MOVE
	cd $KERNEL_DIR
}

DATE_START=$(date +"%s")

echo -e "${green}"
echo "RenderZenith creation script:"
echo -e "${restore}"

while read -p "Do you want to clean stuffs (y/n)? " cchoice
do
case "$cchoice" in
	y|Y )
		checkout_ak3_branches
		clean_all
		echo
		echo "All Cleaned now."
		break
		;;
	n|N )
		checkout_ak3_branches
		break
		;;
	* )
		echo
		echo "Invalid try again!"
		echo
		;;
esac
done

echo

echo "Pick which toolchain to build with:"
select choice in Clang GCC
do
case "$choice" in
	"Clang")
		make_clang_kernel
		break;;
	"GCC")
		make_gcc_kernel
		break;;
esac
done

while read -p "Do you want to ZIP kernel (y/n)? " dchoice
do
case "$dchoice" in
  y|Y)
    make_modules
    make_zip
    break
    ;;
  n|N )
    break
    ;;
  * )
    echo
    echo "Invalid try again!"
    echo
    ;;
esac
done

echo -e "${green}"
echo "-------------------"
echo "Build Completed in:"
echo "-------------------"
echo -e "${restore}"

DATE_END=$(date +"%s")
DIFF=$(($DATE_END - $DATE_START))
echo "Time: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
echo
