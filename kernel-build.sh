#!/usr/bin/env bash
#
# Copyright (C) 2022 a Himemoria
#

msg() {
	echo
	echo -e "\e[1;32m$*\e[0m"
	echo
}

# Directory Info
MAIN_DIR=$(pwd)
CLANG_DIR=$MAIN_DIR/clang-llvm
GCCARM_DIR=$MAIN_DIR/gcc32
GCCARM64_DIR=$MAIN_DIR/gcc64

# Main Declaration
MODEL="Redmi Note 9"
DEVICE_CODENAME=merlin
DEVICE_DEFCONFIG=merlin_defconfig
AK3_BRANCH=merlin
KERNEL_NAME=$(cat "arch/arm64/configs/$DEVICE_DEFCONFIG" | grep "CONFIG_LOCALVERSION=" | sed 's/CONFIG_LOCALVERSION="-*//g' | sed 's/"*//g' )
export KBUILD_BUILD_USER=Himemori
export KBUILD_BUILD_HOST=XZI-TEAM
IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
START=$(date +"%s")
DTB=$(pwd)/out/arch/arm64/boot/dts/mediatek/mt6768.dtb
DTBO=$(pwd)/out/arch/arm64/boot/dtbo.img
DISTRO=$(source /etc/os-release && echo "${NAME}")

# Date
export TZ=Asia/Jakarta
DATE="$(date +"%A, %d %b %Y")"
ZDATE="$(date "+%Y%m%d")"

function clone_clang() {
	msg "+--- Cloning-Clang ---+"
	wget https://raw.githubusercontent.com/Renayura/roselia-clang/main/clang-16.0.0-link.txt -O "link.txt" > /dev/null 2>&1
	wget "$(cat link.txt)" -O "Roselia-Clang.tar.gz" > /dev/null 2>&1
	mkdir clang-llvm && tar -xf Roselia-Clang.tar.gz -C $CLANG_DIR > /dev/null 2>&1 && rm -rf Roselia-Clang.tar.gz link.txt
}

function clone_gcc() {
	msg "+--- Cloning-GCC --+"
	git clone --depth=1 https://github.com/Renayura/gcc-arm -b master "$GCCARM_DIR" > /dev/null 2>&1
        git clone --depth=1 https://github.com/Renayura/gcc-arm64 -b master "$GCCARM64_DIR" > /dev/null 2>&1
}

# Get specify compiler from command
if [[ "$1" == "clang" ]]; then
	clone_clang
	CLANG_VER="$(clang-llvm/bin/clang --version | head -n 1)"
	LLD_VER="$(clang-llvm/bin/ld.lld --version | head -n 1)"
	export KBUILD_COMPILER_STRING="$CLANG_VER with $LLD_VER"
	export PATH="$CLANG_DIR/bin:$PATH"
elif [[ "$1" =~ "gcc" ]]; then
	clone_gcc
	KBUILD_COMPILER_STRING=$("$GCCARM64_DIR"/bin/aarch64-elf-gcc --version | head -n 1)
	PATH="$GCCARM64_DIR/bin/:$GCCARM_DIR/bin/:/usr/bin:$PATH"
fi

if [[ "$2" == "full-lto" ]]; then
	echo "CONFIG_LTO=y" >> arch/arm64/configs/"$DEVICE_DEFCONFIG"
	echo "CONFIG_THINLTO=n" >> arch/arm64/configs/"$DEVICE_DEFCONFIG"
	echo "CONFIG_LTO_CLANG=y" >> arch/arm64/configs/"$DEVICE_DEFCONFIG"
fi

#Check Kernel Version
KERVER=$(make kernelversion)
TERM=xterm
PROCS=$(nproc --all)

# Telegram Setup
git clone --depth=1 https://github.com/fabianonline/telegram.sh Telegram

TELEGRAM="$MAIN_DIR/Telegram/telegram"
tgm() {
  "${TELEGRAM}" -H -D \
      "$(
          for POST in "${@}"; do
              echo "${POST}"
          done
      )"
}

tgf() {
    "${TELEGRAM}" -H \
    -f "$1" \
    "$2"
}

# Post Main Information
tgm "
<b>+----- Starting-Compilation -----+</b>
<b>• Date</b> : <code>$DATE</code>
<b>• Docker OS</b> : <code>$DISTRO</code>
<b>• Device Name</b> : <code>$MODEL ($DEVICE_CODENAME)</code>
<b>• Device Defconfig</b> : <code>$DEVICE_DEFCONFIG</code>
<b>• Kernel Name</b> : <code>${KERNEL_NAME}</code>
<b>• Kernel Version</b> : <code>${KERVER}</code>
<b>• Builder Name</b> : <code>${KBUILD_BUILD_USER}</code>
<b>• Builder Host</b> : <code>${KBUILD_BUILD_HOST}</code>
<b>• Host Core Count</b> : <code>$PROCS</code>
<b>• Compiler</b> : <code>${KBUILD_COMPILER_STRING}</code>
<b>+------------------------------------+</b>
"

if [[ -d "clang-llvm" ]]; then
  MAKE+=(
	CC=clang
	NM=llvm-nm
	CXX=clang++
	AR=llvm-ar
	LD=ld.lld
	STRIP=llvm-strip
	OBJCOPY=llvm-objcopy
	OBJDUMP=llvm-objdump
	OBJSIZE=llvm-size
	READELF=llvm-readelf
	HOSTAR=llvm-ar
	HOSTLD=ld.lld
	HOSTCC=clang
	HOSTCXX=clang++
	CROSS_COMPILE=aarch64-linux-gnu-
	CONFIG_CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
	CLANG_TRIPLE=aarch64-linux-gnu-
	LLVM=1
	LLVM_IAS=1
)
elif [[ -d "gcc64" ]]; then
  MAKE+=(
	CC=aarch64-elf-gcc
    	LD=aarch64-elf-ld.lld
	CROSS_COMPILE=aarch64-elf-
	CONFIG_CROSS_COMPILE_COMPAT=arm-eabi-
	AR=llvm-ar
 	NM=llvm-nm
 	OBJDUMP=llvm-objdump
	OBJCOPY=llvm-objcopy
	OBJSIZE=llvm-objsize
	STRIP=llvm-strip
	HOSTAR=llvm-ar
	HOSTCC=gcc
	HOSTCXX=aarch64-elf-g++
)
fi

# Compile
compile(){
msg "+--- Starting-Compilation ---+"
make -j$(nproc) O=out ARCH=arm64 ${DEVICE_DEFCONFIG}
make -j$(nproc) ARCH=arm64 O=out \
         "${MAKE[@]}" 2>&1 | tee error.log

   if ! [ -a "$IMAGE" ]; then
	finerr
	exit 1
   fi

  git clone --depth=1 https://github.com/Renayura/AnyKernel3 -b ${AK3_BRANCH} AnyKernel
    cp $IMAGE AnyKernel
    cp $DTBO AnyKernel
    mv $DTB AnyKernel/dtb
}

# Push kernel to channel
function push() {
    msg "+--- Starting-Upload ---+"
    cd AnyKernel
    ZIP_NAME=[$KERVER]-$KERNEL_NAME-$DEVICE_CODENAME-R-OSS-$ZDATE.zip
    ZIP=$(echo *.zip)
    MD5CHECK=$(md5sum "${ZIP}" | cut -d' ' -f1)
    SHA1CHECK=$(sha1sum "${ZIP}" | cut -d' ' -f1)
tgm "
<b>+-----------------------------+</b>
✅ <b>Build Success</b>
- <code>$((DIFF / 60)) minute(s) $((DIFF % 60)) second(s) </code>
<b>• MD5 Checksum</b>
- <code>${MD5CHECK}</code>
<b>• SHA1 Checksum</b>
- <code>${SHA1CHECK}</code>
<b>• Zip Name</b>
- <code>${ZIP_NAME}</code>
<b>+-----------------------------+</b>
"

tgf "$ZIP" "$KBUILD_COMPILER_STRING"

}

# Fin Error
function finerr() {
    msg "+--- Sending-Error Log ---+"
    LOG=$(echo error.log)
    tgf "$LOG" "❌ Build Failed. | For <b>${DEVICE_CODENAME}</b> | <b>${KBUILD_COMPILER_STRING}</b>"
    exit 1
}

# Zipping
function zipping() {
    msg "+--- Started Zipping ---+"
    cd AnyKernel || exit 1
    zip -r9 [$KERVER]-$KERNEL_NAME-$DEVICE_CODENAME-R-OSS-$ZDATE.zip *
    cd ..
}
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push

