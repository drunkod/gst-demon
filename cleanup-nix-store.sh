#!/usr/bin/env bash
# cleanup-nix-store.sh
# Aggressive Nix store cleanup to recover 50-80GB

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

echo "════════════════════════════════════════════════════════════"
echo "  Nix Store Cleanup - Space Recovery"
echo "════════════════════════════════════════════════════════════"
echo ""

# Check current size
if command -v du &> /dev/null; then
  BEFORE_SIZE=$(du -sh /nix/store 2>/dev/null | cut -f1 || echo "unknown")
  log_info "Current /nix/store size: $BEFORE_SIZE"
else
  BEFORE_SIZE="unknown"
fi

echo ""
log_warning "This will:"
echo "  1. Delete old generations"
echo "  2. Delete unused derivations"
echo "  3. Optimize the Nix store"
echo "  4. Remove old Android SDK caches"
echo ""

read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  log_info "Cancelled"
  exit 0
fi

echo ""
log_info "Step 1: Deleting old generations..."
nix-collect-garbage --delete-old || log_warning "Some generations couldn't be deleted"

echo ""
log_info "Step 2: Deleting unused store paths..."
nix-store --gc || log_warning "Some paths couldn't be garbage collected"

echo ""
log_info "Step 3: Optimizing store (hardlinking duplicates)..."
nix-store --optimise || log_warning "Store optimization had issues"

echo ""
log_info "Step 4: Cleaning Android SDK caches..."

# Clean Gradle caches
if [ -d "$HOME/.gradle" ]; then
  log_info "Cleaning Gradle cache..."
  rm -rf "$HOME/.gradle/caches" || true
  rm -rf "$HOME/.gradle/wrapper/dists" || true
  GRADLE_SAVED=$(du -sh "$HOME/.gradle" 2>/dev/null | cut -f1 || echo "0")
  log_success "Gradle cleaned (kept: $GRADLE_SAVED)"
fi

# Clean Android SDK build-cache
if [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME" ]; then
  log_info "Cleaning Android SDK build cache..."
  rm -rf "$ANDROID_HOME/build-cache" || true
  rm -rf "$ANDROID_HOME/.temp" || true
  log_success "Android SDK caches cleaned"
fi

# Clean Rust caches
if [ -d "$HOME/.cargo" ]; then
  log_info "Cleaning Rust cargo cache..."
  rm -rf "$HOME/.cargo/registry/cache" || true
  rm -rf "$HOME/.cargo/git/db" || true
  cargo cache -a || true
  CARGO_SIZE=$(du -sh "$HOME/.cargo" 2>/dev/null | cut -f1 || echo "unknown")
  log_success "Cargo cleaned (kept: $CARGO_SIZE)"
fi

# Clean build artifacts
log_info "Cleaning local build artifacts..."
rm -rf /tmp/gstd-android-build || true
rm -rf android-libs || true
log_success "Build artifacts cleaned"

echo ""
log_info "Calculating final size..."

if command -v du &> /dev/null; then
  AFTER_SIZE=$(du -sh /nix/store 2>/dev/null | cut -f1 || echo "unknown")
  
  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "  Cleanup Complete"
  echo "════════════════════════════════════════════════════════════"
  echo ""
  echo "Before: $BEFORE_SIZE"
  echo "After:  $AFTER_SIZE"
  echo ""
fi

log_success "Cleanup complete!"
echo ""
log_info "Additional space-saving tips:"
echo "  • Remove unused Docker images: docker system prune -a"
echo "  • Clean apt cache: sudo apt clean"
echo "  • Remove old kernels: sudo apt autoremove"
echo ""