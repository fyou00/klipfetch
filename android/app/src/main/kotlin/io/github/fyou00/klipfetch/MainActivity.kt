package io.github.fyou00.klipfetch

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var ytDlpHandler: YtDlpChannelHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ytDlpHandler = YtDlpChannelHandler(
            context = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        ytDlpHandler?.dispose()
        ytDlpHandler = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
