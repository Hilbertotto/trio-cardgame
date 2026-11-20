package hu.triogame.trio_android

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private var tones: android.media.ToneGenerator? = null
    override fun configureFlutterEngine(engine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(engine)
        io.flutter.plugin.common.MethodChannel(engine.dartExecutor.binaryMessenger, "hu.triogame/sounds")
            .setMethodCallHandler { call, result ->
                if (call.method != "flip" && call.method != "trio") {
                    result.notImplemented()
                } else {
                    try {
                        val tone = tones ?: android.media.ToneGenerator(android.media.AudioManager.STREAM_MUSIC, 18).also { tones = it }
                        tone.startTone(if (call.method == "trio") android.media.ToneGenerator.TONE_PROP_ACK else android.media.ToneGenerator.TONE_PROP_BEEP, if (call.method == "trio") 180 else 30)
                    } catch (_: RuntimeException) { }
                    result.success(null)
                }
            }
    }
    override fun onDestroy() {
        tones?.release()
        tones = null
        super.onDestroy()
    }
}
