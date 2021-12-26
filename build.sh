#!/usr/bin/env bash
BASEDIR="$(pwd)"
source "${BASEDIR}/stubs/haste"

TELEGRAM="${BASEDIR}/stubs/telegram"
tgPost() { "${TELEGRAM}" -H -D "$(for POST in "${@}"; do echo -e "${POST}"; done)" &>/dev/null; }
tgUpload() { "${TELEGRAM}" -f "${1}" -H "$(for POST in "${@:2}"; do echo -e "${POST}"; done)" &>/dev/null; }

KERNEL_SRC="private/mediatek-realme-oppo6785-4.14"
OUT_DIR="${BASEDIR}/out/${KERNEL_SRC}"
DIST_DIR="${BASEDIR}/out/dist"
AK_DIR="${BASEDIR}/AnyKernel3"

DEVICE="oppo6785"
BUILD_FRAGMENTS="
Image.gz
Image.lz4
mt6785.dtb
"

prepare() {
    cd "${BASEDIR}/${KERNEL_SRC}" || exit

    BRANCH="$(git ls-remote --heads "$(git remote)" | grep "$(git rev-parse HEAD)" | cut -d / -f 3)"
    HEAD="$(git log --pretty=format:"%h (\"%s\")" -1)"

    make -s ARCH=arm64 O="${OUT_DIR}" "${DEVICE}_defconfig"
    KERNEL_VERSION=$(make -s O="${OUT_DIR}" kernelversion)

    cd "${BASEDIR}" || exit
}

build() {
    BUILD_LOG="${BASEDIR}/build-log.txt"
    BUILD_START="$(date +"%s")"

    ./build_oppo6785.sh |& tee "${BUILD_LOG}"

    BUILD_END="$(date +"%s")"
}

post_build() {
    BUILD_DIFF="$((BUILD_END - BUILD_START))"

    if [ -f "${DIST_DIR}/Image.gz" ] || [ -f "${DIST_DIR}/Image.lz4" ]; then
        DATE="$(TZ=Asia/Kolkata date +"%Y%m%d_%H%M%S")"
        ZIP="Makima-${DEVICE}-${DATE}"
        ZIP_SIGNED="${ZIP}-signed.zip"

        cd "${AK_DIR}" || exit
        for BUILD_FRAGMENT in ${BUILD_FRAGMENTS}; do
            if [ -f "${DIST_DIR}/${BUILD_FRAGMENT}" ]; then
                cp -p "${DIST_DIR}/${BUILD_FRAGMENT}" "${AK_DIR}"
            fi
        done
        mv ./*.dtb ./dtb
        zip -r9 "${ZIP}.zip" ./* -x .git zipsigner-3.0-dexed.jar
        java -jar zipsigner-3.0-dexed.jar "${ZIP}.zip" "${ZIP_SIGNED}"

        SHA1SUM="$(sha1sum "${ZIP_SIGNED}" | cut -d ' ' -f 1)"

        tgUpload "${ZIP_SIGNED}" "New #${DEVICE} test build (<b>${KERNEL_VERSION}</b>) with branch <b>${BRANCH}</b> at commit <b>${HEAD}</b>." \
                                 "Build took <b>$((BUILD_DIFF / 60)) minute(s)</b> and <b>$((BUILD_DIFF % 60)) second(s)</b>." \
                                 "<b>SHA-1:</b> <code>${SHA1SUM}</code>" \
                                 "<b>Build log:</b> $(haste "${BUILD_LOG}")"
    else
        tgUpload "${BUILD_LOG}" "#${DEVICE} test build (<b>${KERNEL_VERSION}</b>) with branch <b>${BRANCH}</b> at commit <b>${HEAD}</b> failed in <b>$((BUILD_DIFF / 60)) minute(s)</b> and <b>$((BUILD_DIFF % 60)) second(s)</b>." \
                                "<b>Build log:</b> $(haste "${BUILD_LOG}")"
        exit 1
    fi
}

prepare
build
post_build
