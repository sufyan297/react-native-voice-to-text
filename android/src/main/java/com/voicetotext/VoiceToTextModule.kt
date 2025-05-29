package com.voicetotext

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.core.content.ContextCompat
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.WritableMap
import com.facebook.react.bridge.Arguments
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.modules.core.DeviceEventManagerModule
import java.util.*

@ReactModule(name = VoiceToTextModule.NAME)
class VoiceToTextModule(reactContext: ReactApplicationContext) :
  NativeVoiceToTextSpec(reactContext) {

  private var speechRecognizer: SpeechRecognizer? = null
  private var recognizerIntent: Intent? = null
  private var isListening = false
  private val mainHandler = Handler(Looper.getMainLooper())
  private val TAG = "VoiceToTextModule"
  private val eventListeners = HashMap<String, Int>()
  private var recognitionListener: RecognitionListener? = null

  init {
    mainHandler.post {
      if (SpeechRecognizer.isRecognitionAvailable(reactApplicationContext)) {
        initializeSpeechRecognizer()
      } else {
        sendEvent("onSpeechError", "Speech recognition is not available on this device")
      }
    }
  }

  override fun getName(): String {
    return NAME
  }

  private fun initializeSpeechRecognizer() {
    Log.d(TAG, "Initializing SpeechRecognizer")
    speechRecognizer?.destroy()
    speechRecognizer = SpeechRecognizer.createSpeechRecognizer(reactApplicationContext)
    recognizerIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
      putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
      putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
      putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
      putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
      putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, reactApplicationContext.packageName)
    }

    recognitionListener = object : RecognitionListener {
      override fun onReadyForSpeech(params: Bundle?) {
        Log.d(TAG, "onReadyForSpeech")
        sendEvent("onSpeechStart", null)
      }

      override fun onBeginningOfSpeech() {
        Log.d(TAG, "onBeginningOfSpeech")
        sendEvent("onSpeechBegin", null)
      }

      override fun onRmsChanged(rmsdB: Float) {
        if (eventListeners.containsKey("onSpeechVolumeChanged") && eventListeners["onSpeechVolumeChanged"]!! > 0) {
          val params = Arguments.createMap()
          params.putDouble("value", rmsdB.toDouble())
          sendEvent("onSpeechVolumeChanged", params)
        }
      }

      override fun onBufferReceived(buffer: ByteArray?) {
        if (buffer != null && eventListeners.containsKey("onSpeechAudioBuffer") && eventListeners["onSpeechAudioBuffer"]!! > 0) {
          val params = Arguments.createMap()
          params.putString("buffer", Base64.getEncoder().encodeToString(buffer))
          sendEvent("onSpeechAudioBuffer", params)
        }
      }

      override fun onEndOfSpeech() {
        Log.d(TAG, "onEndOfSpeech")
        isListening = false
        sendEvent("onSpeechEnd", null)
      }

      override fun onError(error: Int) {
        val errorMessage = when (error) {
          SpeechRecognizer.ERROR_NETWORK -> "Network error"
          SpeechRecognizer.ERROR_NO_MATCH -> "No speech match found"
          SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognizer is busy"
          SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
          SpeechRecognizer.ERROR_SERVER -> "Server error"
          SpeechRecognizer.ERROR_CLIENT -> "Client error"
          SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Speech timeout"
          SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
          else -> "Unknown error: $error"
        }

        val params = Arguments.createMap()
        params.putInt("code", error)
        params.putString("message", errorMessage)

        Log.d(TAG, "onError: $errorMessage")
        isListening = false
        sendEvent("onSpeechError", params)
      }

      override fun onResults(results: Bundle?) {
        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        val confidence = results?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)

        val params = Arguments.createMap()

        if (matches != null) {
          val resultsMap = Arguments.createMap()
          val transcriptions = Arguments.createArray()

          for (i in matches.indices) {
            val transcriptionMap = Arguments.createMap()
            transcriptionMap.putString("text", matches[i])
            if (confidence != null && i < confidence.size) {
                transcriptionMap.putDouble("confidence", confidence[i].toDouble())
            } else {
                transcriptionMap.putDouble("confidence", 0.0)
            }
            transcriptions.pushMap(transcriptionMap)
          }

          resultsMap.putArray("transcriptions", transcriptions)
          params.putMap("results", resultsMap)

          params.putString("value", matches.firstOrNull() ?: "")
        }

        Log.d(TAG, "onResults: ${matches?.firstOrNull()}")
        isListening = false
        sendEvent("onSpeechResults", params)
      }

      override fun onPartialResults(partialResults: Bundle?) {
        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)

        val params = Arguments.createMap()

        if (matches != null) {
          val resultsMap = Arguments.createMap()
          val transcriptions = Arguments.createArray()

          for (i in matches.indices) {
            val transcriptionMap = Arguments.createMap()
            transcriptionMap.putString("text", matches[i])
            transcriptions.pushMap(transcriptionMap)
          }

          resultsMap.putArray("transcriptions", transcriptions)
          params.putMap("results", resultsMap)

          params.putString("value", matches.firstOrNull() ?: "")
        }

        Log.d(TAG, "onPartialResults: ${matches?.firstOrNull()}")
        sendEvent("onSpeechPartialResults", params)
      }

      override fun onEvent(eventType: Int, params: Bundle?) {
        if (params != null) {
          val eventParams = Arguments.createMap()
          eventParams.putInt("eventType", eventType)

          for (key in params.keySet()) {
            val value = params.get(key)
            when (value) {
              is String -> eventParams.putString(key, value)
              is Int -> eventParams.putInt(key, value)
              is Double -> eventParams.putDouble(key, value)
              is Boolean -> eventParams.putBoolean(key, value)
            }
          }

          sendEvent("onSpeechEvent", eventParams)
        }
      }
    }

    speechRecognizer?.setRecognitionListener(recognitionListener)
  }

  private fun sendEvent(eventName: String, params: Any?) {
    try {
      if (params is String) {
        reactApplicationContext
          .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
          .emit(eventName, params)
      } else if (params is WritableMap) {
        reactApplicationContext
          .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
          .emit(eventName, params)
      } else {
        reactApplicationContext
          .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
          .emit(eventName, params)
      }
    } catch (e: Exception) {
      Log.e(TAG, "Error sending event: $eventName", e)
    }
  }

  @ReactMethod
  override fun startListening(promise: Promise) {
    if (ContextCompat.checkSelfPermission(reactApplicationContext, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
      promise.reject("PERMISSION_DENIED", "Audio recording permission not granted")
      return
    }

    mainHandler.post {
      if (speechRecognizer == null) {
        promise.reject("NOT_AVAILABLE", "Speech recognition is not available on this device")
        return@post
      }

      if (isListening) {
        Log.d(TAG, "startListening: Speech recognition already in progress")
        promise.reject("ALREADY_LISTENING", "Speech recognition already in progress")
        return@post
      }

      initializeSpeechRecognizer()
      speechRecognizer?.startListening(recognizerIntent)
      isListening = true
      Log.d(TAG, "startListening: Started listening")
      promise.resolve("Started listening")
    }
  }

  @ReactMethod
  override fun stopListening(promise: Promise) {
    mainHandler.post {
      if (speechRecognizer == null) {
        promise.reject("NOT_AVAILABLE", "Speech recognition is not available on this device")
        return@post
      }

      if (!isListening) {
        Log.d(TAG, "stopListening: Speech recognition not in progress")
        promise.resolve("Not listening")
        return@post
      }

      try {
        speechRecognizer?.stopListening()
        isListening = false
        Log.d(TAG, "stopListening: Stopped listening")
        promise.resolve("Stopped listening")
      } catch (e: Exception) {
        Log.e(TAG, "Error stopping speech recognition", e)
        promise.reject("ERROR", "Error stopping speech recognition: ${e.message}")
      }
    }
  }

  @ReactMethod
  override fun destroy(promise: Promise) {
    mainHandler.post {
      speechRecognizer?.destroy()
      isListening = false
      speechRecognizer = null
      eventListeners.clear()
      Log.d(TAG, "destroy: Speech recognizer destroyed")
      promise.resolve("Speech recognizer destroyed")
    }
  }

  @ReactMethod
  override fun addListener(eventName: String) {
    try {
      val count = eventListeners.getOrDefault(eventName, 0)
      eventListeners[eventName] = count + 1

      Log.d(TAG, "addListener: Added listener for $eventName, total: ${eventListeners[eventName]}")
    }
    catch(e: Exception) {
      Log.d(TAG, "addListener: exception: total: ${e.message}", e)
    }
  }

  @ReactMethod
  override fun removeListeners(count: Double) {
    try {
      val countInt = count.toInt()

      for (eventName in eventListeners.keys) {
        val currentCount = eventListeners[eventName] ?: 0
        val newCount = maxOf(0, currentCount - countInt)
        if (newCount > 0) {
          eventListeners[eventName] = newCount
        } else {
          eventListeners.remove(eventName)
        }
      }

      Log.d(TAG, "removeListeners: Removed $count listeners, remaining events: ${eventListeners.keys.joinToString()}")
    } catch(e: Exception) {
      Log.e(TAG, "removeListeners exception: ${e.message}", e)
    }
  }

  @ReactMethod
  override fun getRecognitionLanguage(promise: Promise) {
    val locale = Locale.getDefault()
    val language = locale.language
    val country = locale.country
    val languageTag = if (country.isNotEmpty()) "$language-$country" else language
    promise.resolve(languageTag)
  }

  @ReactMethod
  override fun setRecognitionLanguage(languageTag: String, promise: Promise) {
    try {
      // Ensure we're on the main thread for all SpeechRecognizer operations
      mainHandler.post {
        try {
          recognizerIntent?.putExtra(RecognizerIntent.EXTRA_LANGUAGE, languageTag)
          recognizerIntent?.putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, languageTag)

          val locale = if (languageTag.contains("-")) {
            val parts = languageTag.split("-")
            Locale(parts[0], parts[1])
          } else {
            Locale(languageTag)
          }

          speechRecognizer?.destroy()
          speechRecognizer = SpeechRecognizer.createSpeechRecognizer(reactApplicationContext)
          speechRecognizer?.setRecognitionListener(recognitionListener)

          promise.resolve(true)
        } catch (e: Exception) {
          Log.e(TAG, "Error setting language: $languageTag", e)
          promise.reject("LANGUAGE_ERROR", "Error setting language: ${e.message}")
        }
      }
    } catch (e: Exception) {
      Log.e(TAG, "Error setting language: $languageTag", e)
      promise.reject("LANGUAGE_ERROR", "Error setting language: ${e.message}")
    }
  }

  @ReactMethod
  override fun isRecognitionAvailable(promise: Promise) {
    val isAvailable = SpeechRecognizer.isRecognitionAvailable(reactApplicationContext)
    promise.resolve(isAvailable)
  }

  @ReactMethod
  override fun getSupportedLanguages(promise: Promise) {
    try {
      // Create an array that's compatible with React Native bridge
      val languages = Arguments.createArray()

      // Add common supported languages
      listOf(
        "en-US", "en-GB", "fr-FR", "de-DE", "it-IT", "es-ES",
        "ja-JP", "ko-KR", "zh-CN", "ru-RU", "pt-BR", "nl-NL",
        "hi-IN", "ar-SA"
      ).forEach { language ->
        languages.pushString(language)
      }

      promise.resolve(languages)
    } catch (e: Exception) {
      Log.e(TAG, "Error getting supported languages", e)
      promise.reject("LANGUAGES_ERROR", "Error getting supported languages: ${e.message}")
    }
  }

  companion object {
    const val NAME = "VoiceToText"
  }
}
