#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# GStreamer Android Environment Setup Script
# ============================================================================
# This script extracts the pre-compiled GStreamer binaries for Android
# that were downloaded via Nix into the 'gstreamer-android' directory.

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/gstreamer-android"

# Colors for logging
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================================
# Check for force flag
# ============================================================================

FORCE=false
if [ "${1:-}" = "--force" ] || [ "${1:-}" = "-f" ]; then
  FORCE=true
  log_info "Force mode enabled - will overwrite existing installation"
fi

# ============================================================================
# Check if already exists
# ============================================================================

if [ -d "$OUTPUT_DIR" ] && [ "$FORCE" = false ]; then
  log_info "GStreamer for Android directory already exists at '$OUTPUT_DIR'."
  
  # Verify it's valid
  VALID=true
  for arch_dir in arm64 armv7 x86 x86_64; do
    if [ ! -d "$OUTPUT_DIR/$arch_dir/lib/pkgconfig" ]; then
      log_warning "Architecture $arch_dir appears incomplete"
      VALID=false
    fi
  done
  
  if [ "$VALID" = true ]; then
    log_success "Installation appears valid. Skipping download and extraction."
    log_info "Use --force to reinstall."
    
    echo ""
    log_info "Available architectures:"
    for arch_dir in arm64 armv7 x86 x86_64; do
      if [ -d "$OUTPUT_DIR/$arch_dir" ]; then
        echo "  ✅ $arch_dir"
      fi
    done
    exit 0
  else
    log_warning "Installation appears corrupted. Reinstalling..."
    rm -rf "$OUTPUT_DIR"
  fi
fi

# ============================================================================
# Get GStreamer tarball path from Nix
# ============================================================================

log_info "GStreamer for Android not found or invalid. Starting setup..."
echo ""

# Use the helper script provided by our package
if command -v gstreamer-android-path &> /dev/null; then
  log_info "Getting GStreamer tarball path from Nix environment..."
  GSTREAMER_TARBALL=$(gstreamer-android-path)
else
  log_error "gstreamer-android-path command not found!"
  log_info "Please ensure you're running this from within the Nix development shell."
  log_info "Run: nix develop"
  exit 1
fi

# Verify the tarball exists
if [ ! -f "$GSTREAMER_TARBALL" ]; then
  log_error "GStreamer tarball not found at: $GSTREAMER_TARBALL"
  log_info "The Nix derivation may have failed. Try:"
  log_info "  nix-build --no-out-link -A packages.gstreamerAndroid.source"
  exit 1
fi

log_success "GStreamer tarball found at: $GSTREAMER_TARBALL"

# Show tarball info
TARBALL_SIZE=$(du -h "$GSTREAMER_TARBALL" | cut -f1)
log_info "Tarball size: $TARBALL_SIZE"

# ============================================================================
# Extract the tarball
# ============================================================================

log_info "Creating output directory: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

log_info "Extracting GStreamer binaries..."
echo ""

# Extract with progress
if tar --version 2>&1 | grep -q "GNU tar"; then
  # GNU tar supports --checkpoint for progress
  tar -xJf "$GSTREAMER_TARBALL" -C "$OUTPUT_DIR" --checkpoint=.500
  echo ""
else
  # BSD tar (macOS) or other
  tar -xJf "$GSTREAMER_TARBALL" -C "$OUTPUT_DIR"
fi

# ============================================================================
# Verify extraction
# ============================================================================

log_info "Verifying extraction..."
echo ""

ARCHITECTURES=("arm64" "armv7" "x86" "x86_64")
ALL_VALID=true

for arch in "${ARCHITECTURES[@]}"; do
  if [ -d "$OUTPUT_DIR/$arch" ]; then
    # Check for key directories
    if [ -d "$OUTPUT_DIR/$arch/lib/pkgconfig" ]; then
      PKG_COUNT=$(find "$OUTPUT_DIR/$arch/lib/pkgconfig" -name "*.pc" | wc -l)
      PLUGIN_COUNT=$(find "$OUTPUT_DIR/$arch/lib/gstreamer-1.0" -name "*.so" 2>/dev/null | wc -l || echo 0)
      
      echo "✅ $arch"
      echo "   • pkg-config files: $PKG_COUNT"
      echo "   • GStreamer plugins: $PLUGIN_COUNT"
    else
      echo "⚠️  $arch (incomplete - missing pkgconfig)"
      ALL_VALID=false
    fi
  else
    echo "❌ $arch (not found)"
    ALL_VALID=false
  fi
done

echo ""

if [ "$ALL_VALID" = false ]; then
  log_warning "Some architectures are missing or incomplete"
  log_info "This may be expected depending on the GStreamer package version"
fi

# ============================================================================
# Create convenience symlinks and info file
# ============================================================================

log_info "Creating convenience files..."

# Create a version info file
cat > "$OUTPUT_DIR/GSTREAMER_INFO.txt" << EOF
GStreamer for Android
=====================

Extracted from: $(basename "$GSTREAMER_TARBALL")
Date: $(date)
Source: $GSTREAMER_TARBALL

Architectures:
EOF

for arch in "${ARCHITECTURES[@]}"; do
  if [ -d "$OUTPUT_DIR/$arch" ]; then
    echo "  • $arch" >> "$OUTPUT_DIR/GSTREAMER_INFO.txt"
  fi
done

cat >> "$OUTPUT_DIR/GSTREAMER_INFO.txt" << EOF

Usage:
------
Set PKG_CONFIG_PATH to use these libraries in your build:

  export PKG_CONFIG_PATH="$OUTPUT_DIR/arm64/lib/pkgconfig"

For other architectures, replace 'arm64' with 'armv7', 'x86', or 'x86_64'.

Plugin Path:
  $OUTPUT_DIR/arm64/lib/gstreamer-1.0

Build Script:
  The build-gstd-android script automatically uses these libraries.
EOF

# ============================================================================
# Success summary
# ============================================================================

echo ""
log_success "Successfully extracted GStreamer for Android"
echo ""
log_info "Installation directory: $OUTPUT_DIR"
log_info "See $OUTPUT_DIR/GSTREAMER_INFO.txt for details"
echo ""
log_info "Next steps:"
echo "  1. Verify installation: verify-gstreamer-android"
echo "  2. Build GStreamer Daemon for Android: build-gstd-android"
echo ""

# Run verification if available
if command -v verify-gstreamer-android &> /dev/null; then
  echo "Running verification..."
  echo ""
  verify-gstreamer-android
fi