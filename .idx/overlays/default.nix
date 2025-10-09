# .idx/overlays/default.nix
# Aggregates all overlays in the correct order

[
  # 1. Android SDK must be loaded FIRST
  (import ./android-sdk.nix)
  
  # 2. Cross-compilation setup (depends on SDK)
  (import ./cross-android.nix)
  
  # 3. Expose our patches under a UNIQUE name
  (self: super: {
    # ✅ Use "gstdPatches" instead of "patches" to avoid conflicts
    gstdPatches = {
      asLibrary = ../patches/gstd-as-library.patch;
    };
  })
]