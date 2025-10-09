/*
 * JNI Wrapper for GStreamer Daemon
 *
 * Предоставляет Java/Kotlin интерфейс для управления gstd
 */

#include <jni.h>
#include <android/log.h>
#include <pthread.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>

#define LOG_TAG "GstdNative"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)

// Функции из libgstd.so (которые мы экспортировали в патче)
extern int gstd_start(int argc, char *argv[]);
extern void gstd_stop(void);

// Глобальные переменные
static pthread_t gstd_thread = 0;
static int gstd_running = 0;
static char **gstd_argv = NULL;
static int gstd_argc = 0;

// ============================================================================
// Поток для запуска gstd
// ============================================================================

static void* gstd_thread_func(void* arg) {
    LOGI("GStreamer Daemon thread started");

    int ret = gstd_start(gstd_argc, gstd_argv);

    if (ret != 0) {
        LOGE("gstd_start returned error: %d", ret);
    } else {
        LOGI("gstd_start completed successfully");
    }

    gstd_running = 0;

    return NULL;
}

// ============================================================================
// JNI функции
// ============================================================================

/*
 * Инициализация GStreamer
 * Должна вызываться перед запуском демона
 */
JNIEXPORT jboolean JNICALL
Java_co_realfit_agdkeframe_GstdNative_nativeInit(
    JNIEnv *env,
    jclass clazz,
    jstring jCacheDir,
    jstring jFilesDir
) {
    const char *cache_dir = (*env)->GetStringUTFChars(env, jCacheDir, NULL);
    const char *files_dir = (*env)->GetStringUTFChars(env, jFilesDir, NULL);

    LOGI("Initializing GStreamer");
    LOGD("Cache dir: %s", cache_dir);
    LOGD("Files dir: %s", files_dir);

    // Устанавливаем переменные окружения для GStreamer
    setenv("GST_REGISTRY", cache_dir, 1);
    setenv("GST_PLUGIN_SCANNER", files_dir, 1);

    // Путь к плагинам (в jniLibs они будут в той же директории что и .so)
    char plugin_path[512];
    snprintf(plugin_path, sizeof(plugin_path), "%s/../lib", files_dir);
    setenv("GST_PLUGIN_PATH", plugin_path, 1);

    LOGI("GST_PLUGIN_PATH: %s", plugin_path);

    (*env)->ReleaseStringUTFChars(env, jCacheDir, cache_dir);
    (*env)->ReleaseStringUTFChars(env, jFilesDir, files_dir);

    return JNI_TRUE;
}

/*
 * Запуск GStreamer Daemon
 */
JNIEXPORT jboolean JNICALL
Java_co_realfit_agdkeframe_GstdNative_nativeStart(
    JNIEnv *env,
    jclass clazz,
    jobjectArray jArgs
) {
    if (gstd_running) {
        LOGE("GStreamer Daemon already running");
        return JNI_FALSE;
    }

    // Конвертируем Java String[] в C char**
    gstd_argc = (*env)->GetArrayLength(env, jArgs);
    gstd_argv = (char**)malloc((gstd_argc + 1) * sizeof(char*));

    LOGI("Starting GStreamer Daemon with %d arguments", gstd_argc);

    for (int i = 0; i < gstd_argc; i++) {
        jstring jArg = (jstring)(*env)->GetObjectArrayElement(env, jArgs, i);
        const char *arg = (*env)->GetStringUTFChars(env, jArg, NULL);
        gstd_argv[i] = strdup(arg);
        LOGD("  arg[%d]: %s", i, gstd_argv[i]);
        (*env)->ReleaseStringUTFChars(env, jArg, arg);
        (*env)->DeleteLocalRef(env, jArg);
    }
    gstd_argv[gstd_argc] = NULL;

    // Запускаем gstd в отдельном потоке
    gstd_running = 1;

    int ret = pthread_create(&gstd_thread, NULL, gstd_thread_func, NULL);
    if (ret != 0) {
        LOGE("Failed to create gstd thread: %d", ret);
        gstd_running = 0;

        // Освобождаем память
        for (int i = 0; i < gstd_argc; i++) {
            free(gstd_argv[i]);
        }
        free(gstd_argv);
        gstd_argv = NULL;

        return JNI_FALSE;
    }

    // Даем потоку время на запуск
    usleep(500000); // 500ms

    if (!gstd_running) {
        LOGE("GStreamer Daemon failed to start");
        return JNI_FALSE;
    }

    LOGI("GStreamer Daemon started successfully");
    return JNI_TRUE;
}

/*
 * Остановка GStreamer Daemon
 */
JNIEXPORT void JNICALL
Java_co_realfit_agdkeframe_GstdNative_nativeStop(
    JNIEnv *env,
    jclass clazz
) {
    if (!gstd_running) {
        LOGD("GStreamer Daemon not running");
        return;
    }

    LOGI("Stopping GStreamer Daemon...");

    // Вызываем функцию остановки
    gstd_stop();

    // Ждем завершения потока
    if (gstd_thread != 0) {
        pthread_join(gstd_thread, NULL);
        gstd_thread = 0;
    }

    gstd_running = 0;

    // Освобождаем память
    if (gstd_argv) {
        for (int i = 0; i < gstd_argc; i++) {
            free(gstd_argv[i]);
        }
        free(gstd_argv);
        gstd_argv = NULL;
    }

    LOGI("GStreamer Daemon stopped");
}

/*
 * Проверка статуса
 */
JNIEXPORT jboolean JNICALL
Java_co_realfit_agdkeframe_GstdNative_nativeIsRunning(
    JNIEnv *env,
    jclass clazz
) {
    return gstd_running ? JNI_TRUE : JNI_FALSE;
}

/*
 * Получение версии gstd (опционально)
 */
JNIEXPORT jstring JNICALL
Java_co_realfit_agdkeframe_GstdNative_nativeGetVersion(
    JNIEnv *env,
    jclass clazz
) {
    // Можно экспортировать версию из gstd, пока возвращаем хардкод
    return (*env)->NewStringUTF(env, "0.15.2");
}