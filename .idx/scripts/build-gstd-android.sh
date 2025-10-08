#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# GStreamer Daemon Android Build Script
# ============================================================================
# Собирает gstd и gst-interpipe как библиотеки для Android
# Поддерживает: arm64-v8a, armeabi-v7a, x86_64

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ============================================================================
# Конфигурация
# ============================================================================

# Куда устанавливать собранные библиотеки
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT/android-libs}"

# Временная директория для сборки
BUILD_ROOT="${BUILD_ROOT:-/tmp/gstd-android-build}"

# Архитектуры для сборки (можно передать через переменную окружения)
ARCHITECTURES="${ARCHITECTURES:-arm64-v8a}"

# Версии
INTERPIPE_VERSION="v1.1.10"
GSTD_VERSION="v0.15.2"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Вспомогательные функции
# ============================================================================

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

check_environment() {
  log_info "Проверка окружения..."

  if [ -z "${ANDROID_NDK_HOME:-}" ]; then
    log_error "ANDROID_NDK_HOME не установлен"
    exit 1
  fi

  if [ ! -d "$ANDROID_NDK_HOME" ]; then
    log_error "ANDROID_NDK_HOME указывает на несуществующую директорию: $ANDROID_NDK_HOME"
    exit 1
  fi

  if [ ! -d "$PROJECT_ROOT/gstreamer-android" ]; then
    log_error "GStreamer для Android не найден в $PROJECT_ROOT/gstreamer-android"
    log_info "Запустите setup-android-env или скачайте GStreamer manually"
    exit 1
  fi

  # Проверка доступности компиляторов
  local toolchain="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"
  if [ ! -d "$toolchain" ]; then
    log_error "NDK toolchain не найден: $toolchain"
    exit 1
  fi

  export PATH="$toolchain:$PATH"

  if ! command -v aarch64-linux-android24-clang &> /dev/null; then
    log_error "Компилятор aarch64-linux-android24-clang не найден в PATH"
    exit 1
  fi

  if ! command -v meson &> /dev/null; then
    log_error "Meson не установлен"
    exit 1
  fi

  log_success "Окружение проверено"
}

get_cross_file() {
  local arch=$1
  case $arch in
    arm64-v8a)
      echo "$PROJECT_ROOT/.idx/cross-files/android-aarch64.ini"
      ;;
    armeabi-v7a)
      echo "$PROJECT_ROOT/.idx/cross-files/android-armv7a.ini"
      ;;
    x86_64)
      echo "$PROJECT_ROOT/.idx/cross-files/android-x86_64.ini"
      ;;
    *)
      log_error "Неизвестная архитектура: $arch"
      exit 1
      ;;
  esac
}

get_gst_arch_dir() {
  local arch=$1
  case $arch in
    arm64-v8a)
      echo "arm64"
      ;;
    armeabi-v7a)
      echo "armv7"
      ;;
    x86_64)
      echo "x86_64"
      ;;
    *)
      log_error "Неизвестная архитектура: $arch"
      exit 1
      ;;
  esac
}

# ============================================================================
# Сборка gst-interpipe
# ============================================================================

build_interpipe() {
  local arch=$1
  local install_prefix="$OUTPUT_DIR/$arch"
  local build_dir="$BUILD_ROOT/interpipe-$arch"
  local gst_arch=$(get_gst_arch_dir "$arch")

  log_info "Сборка gst-interpipe для $arch..."

  # Клонируем если нужно
  if [ ! -d "$BUILD_ROOT/gst-interpipe-src" ]; then
    log_info "Клонирование gst-interpipe $INTERPIPE_VERSION..."
    git clone https://github.com/RidgeRun/gst-interpipe.git \
      "$BUILD_ROOT/gst-interpipe-src" \
      --branch "$INTERPIPE_VERSION" \
      --depth 1
  fi

  # Очищаем предыдущую сборку
  rm -rf "$build_dir"
  mkdir -p "$build_dir"
  mkdir -p "$install_prefix"

  # Настраиваем PKG_CONFIG_PATH для GStreamer
  export PKG_CONFIG_PATH="$PROJECT_ROOT/gstreamer-android/$gst_arch/lib/pkgconfig"
  export PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"

  log_info "PKG_CONFIG_PATH: $PKG_CONFIG_PATH"

  # Конфигурация Meson
  local cross_file=$(get_cross_file "$arch")

  cd "$BUILD_ROOT/gst-interpipe-src"

  log_info "Конфигурация Meson..."
  meson setup "$build_dir" \
    --cross-file="$cross_file" \
    --prefix="$install_prefix" \
    --libdir=lib \
    --buildtype=release \
    -Dtests=disabled \
    -Denable-gtk-doc=false \
    -Ddefault_library=shared

  log_info "Компиляция..."
  meson compile -C "$build_dir"

  log_info "Установка..."
  meson install -C "$build_dir"

  # Проверяем результат
  local plugin_path="$install_prefix/lib/gstreamer-1.0/libgstinterpipe.so"
  if [ ! -f "$plugin_path" ]; then
    log_error "Плагин interpipe не найден: $plugin_path"
    exit 1
  fi

  log_success "gst-interpipe собран для $arch"
  log_info "Плагин: $plugin_path"
}

# ============================================================================
# Сборка gstd (как библиотека)
# ============================================================================

build_gstd() {
  local arch=$1
  local install_prefix="$OUTPUT_DIR/$arch"
  local build_dir="$BUILD_ROOT/gstd-$arch"
  local gst_arch=$(get_gst_arch_dir "$arch")

  log_info "Сборка gstd для $arch..."

  # Клонируем если нужно
  if [ ! -d "$BUILD_ROOT/gstd-src" ]; then
    log_info "Клонирование gstd $GSTD_VERSION..."
    git clone https://github.com/RidgeRun/gstd-1.x.git \
      "$BUILD_ROOT/gstd-src" \
      --branch "$GSTD_VERSION" \
      --depth 1
  fi

  # Применяем патч для библиотечной сборки
  cd "$BUILD_ROOT/gstd-src"
  if [ -f "$PROJECT_ROOT/.idx/patches/gstd-as-library.patch" ]; then
    log_info "Применение патча для библиотечной сборки..."
    # Сбрасываем предыдущие изменения
    git reset --hard HEAD
    git clean -fd
    # Применяем патч
    if ! git apply --check "$PROJECT_ROOT/.idx/patches/gstd-as-library.patch" 2>/dev/null; then
      log_warning "Патч уже применен или не применим, продолжаем..."
    else
      git apply "$PROJECT_ROOT/.idx/patches/gstd-as-library.patch"
    fi
  fi

  # Очищаем предыдущую сборку
  rm -rf "$build_dir"
  mkdir -p "$build_dir"

  # Настраиваем PKG_CONFIG_PATH (включаем interpipe)
  export PKG_CONFIG_PATH="$PROJECT_ROOT/gstreamer-android/$gst_arch/lib/pkgconfig:$install_prefix/lib/pkgconfig"
  export PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"

  log_info "PKG_CONFIG_PATH: $PKG_CONFIG_PATH"

  # Конфигурация Meson
  local cross_file=$(get_cross_file "$arch")

  log_info "Конфигурация Meson..."
  meson setup "$build_dir" \
    --cross-file="$cross_file" \
    --prefix="$install_prefix" \
    --libdir=lib \
    --buildtype=release \
    -Denable-tests=disabled \
    -Denable-examples=disabled \
    -Denable-python=disabled \
    -Denable-gtk-doc=false \
    -Denable-systemd=disabled \
    -Denable-initd=disabled \
    -Ddefault_library=shared \
    -Dc_args="-DGSTD_AS_LIBRARY -fvisibility=hidden" \
    -Dcpp_args="-DGSTD_AS_LIBRARY -fvisibility=hidden"

  log_info "Компиляция..."
  meson compile -C "$build_dir"

  log_info "Установка..."
  meson install -C "$build_dir"

  # Проверяем результат
  local lib_path="$install_prefix/lib/libgstd.so"
  if [ ! -f "$lib_path" ]; then
    log_error "Библиотека gstd не найдена: $lib_path"
    exit 1
  fi

  log_success "gstd собран для $arch"
  log_info "Библиотека: $lib_path"
}

# ============================================================================
# Копирование в Android проект
# ============================================================================

copy_to_android_project() {
  local arch=$1
  local jni_libs="$PROJECT_ROOT/agdk-eframe/app/src/main/jniLibs/$arch"

  log_info "Копирование библиотек в Android проект..."

  mkdir -p "$jni_libs"

  # Копируем наши библиотеки
  cp -v "$OUTPUT_DIR/$arch/lib/libgstd.so" "$jni_libs/"
  cp -v "$OUTPUT_DIR/$arch/lib/gstreamer-1.0/libgstinterpipe.so" "$jni_libs/"

  # Копируем необходимые GStreamer библиотеки
  local gst_arch=$(get_gst_arch_dir "$arch")
  local gst_lib_dir="$PROJECT_ROOT/gstreamer-android/$gst_arch/lib"

  if [ -d "$gst_lib_dir" ]; then
    log_info "Копирование GStreamer библиотек..."

    # Основные библиотеки GStreamer (базовые зависимости)
    for lib in \
      libgstreamer-1.0.so \
      libgstbase-1.0.so \
      libglib-2.0.so \
      libgobject-2.0.so \
      libgio-2.0.so \
      libgmodule-2.0.so \
      libgthread-2.0.so \
      libjson-glib-1.0.so \
      libffi.so \
      libintl.so \
      libiconv.so
    do
      if [ -f "$gst_lib_dir/$lib" ]; then
        cp -v "$gst_lib_dir/$lib" "$jni_libs/" || log_warning "$lib не найден"
      fi
    done

    # Плагины GStreamer (опционально, только нужные)
    local gst_plugin_dir="$gst_lib_dir/gstreamer-1.0"
    if [ -d "$gst_plugin_dir" ]; then
      log_info "Копирование базовых GStreamer плагинов..."
      for plugin in \
        libgstcoreelements.so \
        libgstcoretracers.so
      do
        if [ -f "$gst_plugin_dir/$plugin" ]; then
          cp -v "$gst_plugin_dir/$plugin" "$jni_libs/" || true
        fi
      done
    fi
  else
    log_warning "GStreamer библиотеки не найдены в $gst_lib_dir"
  fi

  log_success "Библиотеки скопированы в $jni_libs"

  # Показываем размер
  log_info "Размеры библиотек:"
  ls -lh "$jni_libs"/*.so | awk '{print "  " $9 ": " $5}'
}

# ============================================================================
# Создание информационного файла
# ============================================================================

create_build_info() {
  local info_file="$OUTPUT_DIR/build-info.txt"

  cat > "$info_file" << EOF
GStreamer Daemon Android Build
===============================

Build Date: $(date)
Build Host: $(hostname)
Build User: $(whoami)

Architectures: $ARCHITECTURES

Versions:
  - gst-interpipe: $INTERPIPE_VERSION
  - gstd: $GSTD_VERSION
  - GStreamer: $(pkg-config --modversion gstreamer-1.0 2>/dev/null || echo "N/A")

NDK: $ANDROID_NDK_HOME

Libraries built:
EOF

  for arch in $ARCHITECTURES; do
    echo "" >> "$info_file"
    echo "=== $arch ===" >> "$info_file"
    if [ -f "$OUTPUT_DIR/$arch/lib/libgstd.so" ]; then
      echo "  libgstd.so: $(ls -lh "$OUTPUT_DIR/$arch/lib/libgstd.so" | awk '{print $5}')" >> "$info_file"
    fi
    if [ -f "$OUTPUT_DIR/$arch/lib/gstreamer-1.0/libgstinterpipe.so" ]; then
      echo "  libgstinterpipe.so: $(ls -lh "$OUTPUT_DIR/$arch/lib/gstreamer-1.0/libgstinterpipe.so" | awk '{print $5}')" >> "$info_file"
    fi
  done

  log_success "Build info: $info_file"
}

# ============================================================================
# Главная функция
# ============================================================================

main() {
  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "  GStreamer Daemon Android Build"
  echo "════════════════════════════════════════════════════════════"
  echo ""

  check_environment

  log_info "Архитектуры для сборки: $ARCHITECTURES"
  log_info "Выходная директория: $OUTPUT_DIR"
  log_info "Временная директория: $BUILD_ROOT"
  echo ""

  # Создаем директории
  mkdir -p "$BUILD_ROOT"
  mkdir -p "$OUTPUT_DIR"

  # Собираем для каждой архитектуры
  for arch in $ARCHITECTURES; do
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  Сборка для $arch"
    echo "════════════════════════════════════════════════════════════"
    echo ""

    build_interpipe "$arch"
    echo ""
    build_gstd "$arch"
    echo ""
    copy_to_android_project "$arch"
  done

  echo ""
  create_build_info

  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "  ✅ Сборка завершена успешно!"
  echo "════════════════════════════════════════════════════════════"
  echo ""
  log_info "Библиотеки установлены в:"
  echo "  • $OUTPUT_DIR"
  echo "  • $PROJECT_ROOT/agdk-eframe/app/src/main/jniLibs/"
  echo ""
  log_info "Следующие шаги:"
  echo "  1. Создать JNI wrapper для вызова gstd_start/gstd_stop"
  echo "  2. Загрузить библиотеки в Android приложении"
  echo "  3. Собрать APK: cd agdk-eframe && ./build-apk"
  echo ""
  log_info "Для очистки: rm -rf $BUILD_ROOT $OUTPUT_DIR"
  echo ""
}

# Обработка аргументов
case "${1:-}" in
  clean)
    log_info "Очистка..."
    rm -rf "$BUILD_ROOT" "$OUTPUT_DIR"
    log_success "Очистка завершена"
    exit 0
    ;;
  help|--help|-h)
    cat << EOF
Использование: $0 [команда]

Команды:
  (нет)      - Собрать gstd и interpipe для Android
  clean      - Очистить временные файлы и выходные библиотеки
  help       - Показать эту справку

Переменные окружения:
  ARCHITECTURES  - Архитектуры для сборки (по умолчанию: arm64-v8a)
                   Пример: ARCHITECTURES="arm64-v8a armeabi-v7a"
  OUTPUT_DIR     - Куда установить библиотеки
  BUILD_ROOT     - Временная директория для сборки

Примеры:
  # Собрать только для ARM64
  $0

  # Собрать для всех архитектур
  ARCHITECTURES="arm64-v8a armeabi-v7a x86_64" $0

  # Очистить всё
  $0 clean
EOF
    exit 0
    ;;
  *)
    main "$@"
    ;;
esac