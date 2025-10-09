# GStreamer Daemon Android Build System

This document outlines the process for building the GStreamer Daemon (`gstd`) and its dependencies for use in the Android application. The build system is managed through a combination of Nix, shell scripts, and Meson.

## Quick Start

To build the necessary libraries for Android, follow these two steps from the root of the repository:

1.  **Set up the GStreamer for Android Environment:**
    ```bash
    setup-android-env
    ```
    This command downloads and extracts the pre-compiled GStreamer binaries for Android into the `gstreamer-android/` directory. This only needs to be run once.

2.  **Build the GStreamer Daemon for Android:**
    ```bash
    build-gstd-android
    ```
    This script cross-compiles `gstd` and `gst-interpipe` as shared libraries (`.so` files) and copies them, along with the necessary GStreamer dependencies, into the `agdk-eframe/app/src/main/jniLibs/` directory.

## Build System Components

The build system is composed of several key components:

### 1. Setup Script (`.idx/scripts/setup-android-env.sh`)

-   **Purpose**: To download and install the pre-compiled GStreamer for Android binaries, which are a prerequisite for building `gstd`.
-   **Mechanism**: It uses `nix-build` to fetch the GStreamer binaries from the URL specified in `.idx/modules/config.nix`. The downloaded tarball is then extracted into `gstreamer-android/`.
-   **Integration**: The script is made available as the `setup-android-env` command in the development shell via the Nix module at `.idx/modules/scripts/`.

### 2. Build Script (`.idx/scripts/build-gstd-android.sh`)

-   **Purpose**: To cross-compile `gstd` and `gst-interpipe` for Android.
-   **Architectures**: By default, it builds for `arm64-v8a`. You can specify other architectures via the `ARCHITECTURES` environment variable (e.g., `ARCHITECTURES="arm64-v8a armeabi-v7a x86_64"`).
-   **Process**:
    1.  Clones the `gstd` and `gst-interpipe` source code from their respective GitHub repositories.
    2.  Applies the `.idx/patches/gstd-as-library.patch` to modify the `gstd` build to produce a shared library instead of an executable.
    3.  Uses Meson with the appropriate cross-compilation file (from `.idx/cross-files/`) to build the libraries.
    4.  Copies the final `.so` files into the Android project's `jniLibs` directory, ready to be bundled into the APK.

### 3. Meson Cross-Compilation Files (`.idx/cross-files/`)

-   These `.ini` files configure the Meson build system to use the Android NDK toolchain for cross-compilation. There is one file for each target architecture (`aarch64`, `armv7a`, `x86_64`).

### 4. Patch File (`.idx/patches/gstd-as-library.patch`)

-   This patch is crucial for the Android port. It modifies the `gstd` source code in two ways:
    1.  It changes the `meson.build` file to produce a shared library (`libgstd.so`) when building for Android.
    2.  It refactors the `main` function into `gstd_main_impl` and adds new exported functions (`gstd_start`, `gstd_stop`) that allow the daemon to be started and stopped from the JNI wrapper.

### 5. JNI and Kotlin Integration

-   **JNI Wrapper** (`agdk-eframe/app/src/main/cpp/gstd_wrapper.c`): This C code provides the "glue" between the Java/Kotlin world and the native `libgstd.so` library. It exposes the `gstd_start` and `gstd_stop` functions to the Android app.
-   **Kotlin Interface** (`agdk-eframe/app/src/main/java/co/realfit/agdkeframe/GstdNative.kt`): This provides a clean, high-level Kotlin API for the Android app to interact with the JNI wrapper, handling library loading and providing simple `start()` and `stop()` methods.

## Nix Environment Integration

The entire build process is integrated into the Nix development environment.

-   `.idx/modules/config.nix`: Defines the version, URL, and hash for the GStreamer for Android download.
-   `.idx/modules/gstreamer-android/`: Contains the Nix derivation for fetching the GStreamer binaries.
-   `.idx/modules/packages.nix`: Adds the `setup-android-env` and `build-gstd-android` commands to the shell's `PATH`.

This setup ensures that the build environment is reproducible and that all necessary tools and dependencies are available.