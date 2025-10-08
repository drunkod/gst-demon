#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# GStreamer Android Environment Setup Script
# ============================================================================
# This script downloads the pre-compiled GStreamer binaries for Android
# using Nix and extracts them into the 'gstreamer-android' directory.

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/gstreamer-android"

# Colors for logging
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# 1. Check if the directory already exists
if [ -d "$OUTPUT_DIR" ]; then
  log_info "GStreamer for Android directory already exists at '$OUTPUT_DIR'."
  log_info "Skipping download and extraction."
  exit 0
fi

log_info "GStreamer for Android not found. Starting download..."

# 2. Use nix-build to download the GStreamer tarball
#    The -A gstreamerAndroid.source attribute points to the fetchurl derivation
#    in our Nix configuration.
log_info "Running nix-build to fetch GStreamer binaries..."
GSTREAMER_TARBALL=$(nix-build --no-out-link -A gstreamerAndroid.source)

if [ -z "$GSTREAMER_TARBALL" ]; then
    log_error "nix-build failed to return the path to the GStreamer tarball."
    exit 1
fi

log_success "GStreamer tarball downloaded to: $GSTREAMER_TARBALL"

# 3. Create the output directory
log_info "Creating output directory: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# 4. Extract the tarball into the output directory
log_info "Extracting GStreamer binaries..."
tar -xJf "$GSTREAMER_TARBALL" -C "$OUTPUT_DIR"

log_success "Successfully extracted GStreamer for Android."
log_info "You can now run 'build-gstd-android.sh' to build the daemon."
echo ""
log_info "Directory structure:"
ls -l "$OUTPUT_DIR"