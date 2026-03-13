import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Supported audio encodings.
enum AudioFormat {
  ENCODING_PCM_16BIT,
  ENCODING_PCM_8BIT,
  ENCODING_PCM_FLOAT,
}

/// Channel configuration for microphone capture.
enum ChannelConfig {
  CHANNEL_IN_MONO,
  CHANNEL_IN_STEREO,
}

/// Provides microphone PCM data as a byte stream.
class MicStream {
  static const MethodChannel _methodChannel = MethodChannel('mic_stream');
  static const EventChannel _eventChannel = EventChannel('mic_stream/events');

  /// Starts the microphone and returns a stream of PCM audio frames.
  static Future<Stream<Uint8List>> microphone({
    AudioFormat audioFormat = AudioFormat.ENCODING_PCM_16BIT,
    int sampleRate = 44100,
    ChannelConfig channelConfig = ChannelConfig.CHANNEL_IN_MONO,
  }) async {
    await _methodChannel.invokeMethod('start', {
      'audioFormat': audioFormat.index,
      'sampleRate': sampleRate,
      'channelConfig': channelConfig.index,
    });

    return _eventChannel
        .receiveBroadcastStream()
        .map((data) => data as Uint8List);
  }

  /// Stops the microphone stream if running.
  static Future<void> stop() async {
    try {
      await _methodChannel.invokeMethod('stop');
    } catch (e, st) {
      if (kDebugMode) {
        // Ignore stop failures in release builds.
        // In debug, surface them to help diagnose issues.
        // The print is intentional because logger may not be available here.
        // ignore: avoid_print
        print('MicStream.stop error: $e\n$st');
      }
    }
  }
}
