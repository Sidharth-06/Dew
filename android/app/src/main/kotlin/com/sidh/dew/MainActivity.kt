package com.sidh.dew

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothHeadset
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "dew.app/audio"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isBluetoothAudioConnected" -> {
                    val isConnected = isBluetoothAudioConnected()
                    result.success(isConnected)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isBluetoothAudioConnected(): Boolean {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        
        // Check if Bluetooth A2DP or SCO is connected
        val isA2dpConnected = audioManager.isBluetoothA2dpOn
        val isScoConnected = audioManager.isBluetoothScoOn
        
        // Check wired headphones as well
        val isWiredHeadsetConnected = audioManager.isWiredHeadsetOn
        
        // Also check if any Bluetooth audio device is connected via BluetoothAdapter
        val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        var hasConnectedBluetoothAudio = false
        
        if (bluetoothAdapter?.isEnabled == true) {
            try {
                val connectedDevices = bluetoothAdapter.getBondedDevices()
                for (device in connectedDevices) {
                    // This is a simplified check - in a real app you might want to check the specific profile
                    if (device.bluetoothClass?.majorDeviceClass == 1024) { // Audio/Video major class
                        hasConnectedBluetoothAudio = true
                        break
                    }
                }
            } catch (e: SecurityException) {
                // Handle permission issues
                println("Bluetooth permission not granted: ${e.message}")
            }
        }
        
        return isA2dpConnected || isScoConnected || isWiredHeadsetConnected || hasConnectedBluetoothAudio
    }
}
