package co.realfit.agdkeframe

import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {
    companion object {
        private const val TAG = "MainActivity"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 1. Загрузка нативных библиотек
        if (!GstdNative.loadLibraries()) {
            Log.e(TAG, "Failed to load native libraries")
            finish()
            return
        }

        // 2. Инициализация GStreamer
        if (!GstdNative.init(this)) {
            Log.e(TAG, "Failed to initialize GStreamer")
            finish()
            return
        }

        // 3. Запуск GStreamer Daemon
        if (GstdNative.start()) {
            Log.i(TAG, "GStreamer Daemon started successfully")
            Log.i(TAG, "HTTP API: http://127.0.0.1:8080")
            Log.i(TAG, "TCP Client: 127.0.0.1:5000")
        } else {
            Log.e(TAG, "Failed to start GStreamer Daemon")
        }

        // Ваш UI код здесь...
    }

    override fun onDestroy() {
        super.onDestroy()

        // Останавливаем демон при закрытии приложения
        if (GstdNative.isRunning()) {
            Log.i(TAG, "Stopping GStreamer Daemon")
            GstdNative.stop()
        }
    }
}