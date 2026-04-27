#!/bin/bash
# Build script for note-core native library
# Prerequisites: rustup, aarch64-linux-gnu-gcc, nodejs headers
set -e

NATIVE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="aarch64-unknown-linux-gnu"
RELEASE_DIR="$NATIVE_DIR/target/$TARGET/release"
CC="aarch64-linux-gnu-gcc"
NODE_INCLUDE="/usr/include/node"

echo "==> Building Rust staticlib for $TARGET ..."
cd "$NATIVE_DIR"
cargo build --target "$TARGET" --release

echo "==> Linking NAPI bridge with Rust staticlib ..."
$CC -shared -fPIC \
    -I"$NODE_INCLUDE" \
    "$NATIVE_DIR/src/napi_bridge.c" \
    "$RELEASE_DIR/libnote_core.a" \
    -lpthread -ldl -lm \
    -o "$RELEASE_DIR/libnote_core.so"

echo "==> Stripping debug info ..."
aarch64-linux-gnu-strip "$RELEASE_DIR/libnote_core.so"

echo "==> Done: $RELEASE_DIR/libnote_core.so"
file "$RELEASE_DIR/libnote_core.so"
du -h "$RELEASE_DIR/libnote_core.so"
