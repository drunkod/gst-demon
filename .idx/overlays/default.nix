# .idx/overlays/default.nix
# Aggregates all overlays in the correct order

# IMPORTANT: This file returns a LIST, not a function
[
  # 1. Android SDK must be loaded FIRST
  (import ./android-sdk.nix)
  
  # 2. Cross-compilation setup (depends on SDK)
  (import ./cross-android.nix)
  
  # 3. Expose patches
  (self: super: {
    patches = (super.patches or {}) // {
      gstd-as-library = ../patches/gstd-as-library.patch;
    };
  })
]