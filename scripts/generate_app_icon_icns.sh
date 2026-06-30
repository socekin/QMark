#!/bin/sh
set -eu

APP_ICON_SOURCE="${SRCROOT}/QMark/Assets.xcassets/AppIcon.appiconset"
APP_ICON_OUTPUT="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/AppIcon.icns"
APP_ICON_WORK_DIR="${DERIVED_FILE_DIR}/QMarkAppIcon.iconset"

rm -rf "${APP_ICON_WORK_DIR}"
mkdir -p "${APP_ICON_WORK_DIR}"

cp "${APP_ICON_SOURCE}/icon_16x16.png" "${APP_ICON_WORK_DIR}/icon_16x16.png"
cp "${APP_ICON_SOURCE}/icon_32x32.png" "${APP_ICON_WORK_DIR}/icon_16x16@2x.png"
cp "${APP_ICON_SOURCE}/icon_32x32.png" "${APP_ICON_WORK_DIR}/icon_32x32.png"
cp "${APP_ICON_SOURCE}/icon_64x64.png" "${APP_ICON_WORK_DIR}/icon_32x32@2x.png"
cp "${APP_ICON_SOURCE}/icon_128x128.png" "${APP_ICON_WORK_DIR}/icon_128x128.png"
cp "${APP_ICON_SOURCE}/icon_256x256.png" "${APP_ICON_WORK_DIR}/icon_128x128@2x.png"
cp "${APP_ICON_SOURCE}/icon_256x256.png" "${APP_ICON_WORK_DIR}/icon_256x256.png"
cp "${APP_ICON_SOURCE}/icon_512x512.png" "${APP_ICON_WORK_DIR}/icon_256x256@2x.png"
cp "${APP_ICON_SOURCE}/icon_512x512.png" "${APP_ICON_WORK_DIR}/icon_512x512.png"
cp "${APP_ICON_SOURCE}/icon_1024x1024.png" "${APP_ICON_WORK_DIR}/icon_512x512@2x.png"

/usr/bin/iconutil -c icns "${APP_ICON_WORK_DIR}" -o "${APP_ICON_OUTPUT}"
