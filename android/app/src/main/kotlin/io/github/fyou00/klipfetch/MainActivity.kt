package io.github.fyou00.klipfetch

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var ytDlpHandler: YtDlpChannelHandler? = null
    private var platformHandler: AndroidPlatformHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        ytDlpHandler = YtDlpChannelHandler(
            context = this,
            messenger = messenger,
        )
        platformHandler = AndroidPlatformHandler(
            activity = this,
            messenger = messenger,
        ).apply {
            handleIntent(intent)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        platformHandler?.handleIntent(intent)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (platformHandler?.onRequestPermissionsResult(requestCode, grantResults) == true) {
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (platformHandler?.onActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        ytDlpHandler?.dispose()
        ytDlpHandler = null
        platformHandler?.dispose()
        platformHandler = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
