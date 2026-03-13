package com.code.aaron.micstream

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Process
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class MicStreamPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var recorder: AudioRecord? = null
    private var recordingThread: Thread? = null
    private var sink: EventChannel.EventSink? = null
    private val isRecording = AtomicBoolean(false)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "mic_stream")
        methodChannel?.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "mic_stream/events")
        eventChannel?.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopRecording()
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                startRecording(args)
                result.success(null)
            }
            "stop" -> {
                stopRecording()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        stopRecording()
        sink = null
    }

    private fun startRecording(args: Map<*, *>) {
        if (isRecording.get()) return

        val sampleRate = (args["sampleRate"] as? Number)?.toInt() ?: 44100
        val channelConfigIndex = (args["channelConfig"] as? Number)?.toInt() ?: 0
        val audioFormatIndex = (args["audioFormat"] as? Number)?.toInt() ?: 0

        val channelConfig = if (channelConfigIndex == 1) {
            AudioFormat.CHANNEL_IN_STEREO
        } else {
            AudioFormat.CHANNEL_IN_MONO
        }

        val audioFormat = when (audioFormatIndex) {
            1 -> AudioFormat.ENCODING_PCM_8BIT
            2 -> AudioFormat.ENCODING_PCM_FLOAT
            else -> AudioFormat.ENCODING_PCM_16BIT
        }

        val bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
        if (bufferSize == AudioRecord.ERROR || bufferSize == AudioRecord.ERROR_BAD_VALUE) {
            sink?.error("init", "Invalid audio configuration", null)
            return
        }

        recorder = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            sampleRate,
            channelConfig,
            audioFormat,
            bufferSize * 2,
        )

        if (recorder?.state != AudioRecord.STATE_INITIALIZED) {
            sink?.error("init", "AudioRecord failed to initialize", null)
            recorder?.release()
            recorder = null
            return
        }

        recorder?.startRecording()
        isRecording.set(true)

        recordingThread = Thread {
            android.os.Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)
            val buffer = ByteArray(bufferSize)
            while (isRecording.get()) {
                val read = recorder?.read(buffer, 0, buffer.size) ?: break
                if (read > 0) {
                    sink?.success(buffer.copyOf(read))
                }
            }
        }.also { it.start() }
    }

    private fun stopRecording() {
        isRecording.set(false)
        try {
            recorder?.stop()
        } catch (_: Throwable) {
        }
        recorder?.release()
        recorder = null
        recordingThread?.interrupt()
        recordingThread = null
    }
}
