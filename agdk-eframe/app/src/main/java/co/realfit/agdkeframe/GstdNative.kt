package co.realfit.agdkeframe

import android.content.Context
import android.util.Log

/**
 * JNI интерфейс для GStreamer Daemon
 *
 * Управляет жизненным циклом gstd на Android
 */
object GstdNative {
    private const val TAG = "GstdNative"

    // Библиотеки загружаются в правильном порядке зависимостей
    private val LIBRARIES = arrayOf(
        // 1. Базовые GLib зависимости
        "glib-2.0",
        "gobject-2.0",
        "gio-2.0",
        "gmodule-2.0",

        // 2. Вспомогательные библиотеки
        "ffi",
        "intl",
        "iconv",
        "json-glib-1.0",

        // 3. GStreamer core
        "gstreamer-1.0",
        "gstbase-1.0",

        // 4. Наши плагины и демон
        "gstinterpipe",
        "gstd"
    )

    /**
     * Загрузка всех нативных библиотек
     */
    fun loadLibraries(): Boolean {
        var allLoaded = true

        for (lib in LIBRARIES) {
            try {
                System.loadLibrary(lib)
                Log.d(TAG, "Loaded library: $lib")
            } catch (e: UnsatisfiedLinkError) {
                Log.e(TAG, "Failed to load library: $lib", e)
                allLoaded = false

                // Для некоторых библиотек это не критично
                if (lib in arrayOf("ffi", "intl", "iconv")) {
                    Log.w(TAG, "Continuing despite missing optional library: $lib")
                    allLoaded = true
                } else {
                    break
                }
            }
        }

        return allLoaded
    }

    /**
     * Инициализация GStreamer окружения
     */
    fun init(context: Context): Boolean {
        val cacheDir = context.cacheDir.absolutePath
        val filesDir = context.filesDir.absolutePath

        Log.i(TAG, "Initializing GStreamer")
        Log.d(TAG, "Cache dir: $cacheDir")
        Log.d(TAG, "Files dir: $filesDir")

        return try {
            nativeInit(cacheDir, filesDir)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize GStreamer", e)
            false
        }
    }

    /**
     * Запуск GStreamer Daemon
     *
     * @param args Аргументы командной строки для gstd
     * @return true если запуск успешен
     */
    fun start(args: Array<String> = defaultArgs()): Boolean {
        Log.i(TAG, "Starting GStreamer Daemon")
        Log.d(TAG, "Arguments: ${args.joinToString(" ")}")

        return try {
            nativeStart(args)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start GStreamer Daemon", e)
            false
        }
    }

    /**
     * Остановка GStreamer Daemon
     */
    fun stop() {
        Log.i(TAG, "Stopping GStreamer Daemon")

        try {
            nativeStop()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping GStreamer Daemon", e)
        }
    }

    /**
     * Проверка статуса демона
     */
    fun isRunning(): Boolean {
        return try {
            nativeIsRunning()
        } catch (e: Exception) {
            Log.e(TAG, "Error checking daemon status", e)
            false
        }
    }

    /**
     * Получение версии gstd
     */
    fun getVersion(): String {
        return try {
            nativeGetVersion()
        } catch (e: Exception) {
            Log.e(TAG, "Error getting version", e)
            "unknown"
        }
    }

    /**
     * Аргументы по умолчанию для gstd на Android
     */
    private fun defaultArgs(): Array<String> {
        return arrayOf(
            "gstd",
            "--enable-http-protocol",
            "--http-address=127.0.0.1",  // Только localhost на Android!
            "--http-port=8080",
            "--enable-tcp-protocol",
            "--tcp-address=127.0.0.1",
            "--tcp-base-port=5000",
            "-q"  // Quiet mode
        )
    }

    // Native методы
    private external fun nativeInit(cacheDir: String, filesDir: String): Boolean
    private external fun nativeStart(args: Array<String>): Boolean
    private external fun nativeStop()
    private external fun nativeIsRunning(): Boolean
    private external fun nativeGetVersion(): String
}