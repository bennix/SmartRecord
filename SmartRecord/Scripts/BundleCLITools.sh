set -eu

WHISPER_SRC="${SRCROOT}/Vendor/Whisper"
FFMPEG_SRC="${SRCROOT}/Vendor/FFmpeg"
DST="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/Tools"
TOOL_ENTITLEMENTS="${SRCROOT}/SmartRecord/Tool.entitlements"

WHISPER_LIBS="libggml-base.0.dylib libggml-blas.0.dylib libggml-cpu.0.dylib libggml-metal.0.dylib libggml.0.dylib libwhisper.1.dylib"
FFMPEG_LIBS="libSvtAv1Enc.4.dylib libavcodec.62.dylib libavdevice.62.dylib libavfilter.11.dylib libavformat.62.dylib libavutil.60.dylib libdav1d.7.dylib libmp3lame.0.dylib libopus.0.dylib libswresample.6.dylib libswscale.9.dylib libvpx.11.dylib libx264.165.dylib libx265.215.dylib"

mkdir -p "$DST/bin" "$DST/lib"

/bin/cp -f "$WHISPER_SRC/bin/whisper-cli" "$DST/bin/whisper-cli"
/bin/cp -f "$FFMPEG_SRC/bin/ffmpeg" "$DST/bin/ffmpeg"
chmod 755 "$DST/bin/whisper-cli" "$DST/bin/ffmpeg"

for lib in $WHISPER_LIBS; do
    /bin/cp -f "$WHISPER_SRC/lib/$lib" "$DST/lib/$lib"
    chmod 755 "$DST/lib/$lib"
done

for lib in $FFMPEG_LIBS; do
    /bin/cp -f "$FFMPEG_SRC/lib/$lib" "$DST/lib/$lib"
    chmod 755 "$DST/lib/$lib"
done

sign_file() {
    path="$1"
    entitlements="${2:-}"

    if [ "${CODE_SIGNING_ALLOWED:-NO}" != "YES" ]; then
        return 0
    fi

    identity="${EXPANDED_CODE_SIGN_IDENTITY:-}"
    if [ -z "$identity" ] || [ "$identity" = "-" ]; then
        return 0
    fi

    if [ -n "$entitlements" ]; then
        /usr/bin/codesign --force --sign "$identity" --options runtime --entitlements "$entitlements" "$path"
    else
        /usr/bin/codesign --force --sign "$identity" --options runtime "$path"
    fi
}

emit_dsym() {
    path="$1"
    name="$(basename "$path")"

    if [ -z "${DWARF_DSYM_FOLDER_PATH:-}" ]; then
        return 0
    fi
    if ! command -v dsymutil >/dev/null 2>&1; then
        return 0
    fi

    mkdir -p "$DWARF_DSYM_FOLDER_PATH"
    dsymutil "$path" -o "$DWARF_DSYM_FOLDER_PATH/$name.dSYM" >/dev/null 2>&1 || true
}

for lib in "$DST"/lib/*.dylib; do
    emit_dsym "$lib"
    sign_file "$lib"
done

sign_file "$DST/bin/whisper-cli" "$TOOL_ENTITLEMENTS"
sign_file "$DST/bin/ffmpeg" "$TOOL_ENTITLEMENTS"
emit_dsym "$DST/bin/whisper-cli"
emit_dsym "$DST/bin/ffmpeg"
