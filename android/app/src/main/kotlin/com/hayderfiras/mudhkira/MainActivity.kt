package com.hayderfiras.mudhkira

import android.app.Activity
import android.content.Intent
import android.speech.RecognizerIntent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.hayderfiras.mudhkira/voice"
    private var resultMethod: MethodChannel.Result? = null
    private val VOICE_REQUEST_CODE = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startVoiceRecognition") {
                resultMethod = result
                startVoiceRecognition()
            } else {
                result.notImplemented()
            }
        }
    }

    private fun startVoiceRecognition() {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ar-SA")
        intent.putExtra(RecognizerIntent.EXTRA_PROMPT, "تحدث الآن...")
        
        // محاولة زيادة وقت الصمت المسموح به (قد تختلف الاستجابة حسب الجهاز)
        intent.putExtra("android.speech.extra.SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS", 20000L) // 20 ثانية للصمت التام
        intent.putExtra("android.speech.extra.SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS", 20000L) // 20 ثانية للصمت المحتمل
        intent.putExtra("android.speech.extra.SPEECH_INPUT_MINIMUM_LENGTH_MILLIS", 30000L) // الحد الأدنى
        
        try {
            startActivityForResult(intent, VOICE_REQUEST_CODE)
        } catch (e: Exception) {
            resultMethod?.error("UNAVAILABLE", "Voice recognition not available", null)
            resultMethod = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VOICE_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val results = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                val spokenText = results?.get(0) ?: ""
                resultMethod?.success(spokenText)
            } else {
                // User canceled or error
                resultMethod?.error("CANCELED", "Voice recognition canceled", null)
            }
            resultMethod = null
        }
    }
}
