package ug.go.kcca.weyonje.weyonje

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var smsRetriever: WeyonjeSmsRetriever? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        smsRetriever = WeyonjeSmsRetriever(this, flutterEngine.dartExecutor.binaryMessenger)
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        smsRetriever?.dispose()
        smsRetriever = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
