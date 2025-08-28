import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class YAMNetTFLiteClassifier {
  // Constants based on the TFLite model's requirements
  static const int sampleRate = 16000;
  static const double bufferDurationSeconds =
      0.975; // YAMNet TFLite expects 0.975s
  static final int bufferSize =
      (sampleRate * bufferDurationSeconds).round(); // 15600 samples

  // Minimum confidence threshold for reliable classification
  static const double confidenceThreshold = 0.10; // 10%

  // Exponential moving average factor for smoothing predictions
  static const double smoothingFactor = 0.7;

  Interpreter? _interpreter;
  List<String> _classNames = [];
  bool _isInitialized = false;
  Map<String, double> _lastPrediction = {'Unknown': 1.0};

  // Output tensor shapes (for verification and buffer allocation)
  List<int> _outputScoresShape = [];

  // Environmental category indices for better classification
  final Map<String, List<int>> _categoryIndices = {
    'Speech': [], // Will be populated with indices during initialization
    'Music': [],
    'Noise': [],
    'Nature': [],
    'Quiet': []
  };

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load the TFLite model from assets
      _interpreter = await Interpreter.fromAsset('assets/models/1.tflite',
          options: InterpreterOptions()..threads = 4 // Use multithreading
          );
      print('TFLite model loaded successfully.');

      // Allocate tensors
      _interpreter!.allocateTensors();

      // Get model input and output details
      _printModelInfo();

      // Load class names from the CSV file
      await _loadClassNames();

      // Initialize category indices
      _initializeCategoryIndices();

      _isInitialized = true;
      print('YAMNet TFLite classifier initialized successfully');

      // Test the classifier immediately after initialization
    } catch (e) {
      print('Error initializing YAMNet TFLite classifier: $e');
      rethrow;
    }
  }

  void _initializeCategoryIndices() {
    // Map specific YAMNet classes to our environment categories based on class names
    for (int i = 0; i < _classNames.length; i++) {
      final className = _classNames[i].toLowerCase();

      // Speech related classes
      if (className.contains('speech') ||
          className.contains('talk') ||
          className.contains('conversation') ||
          className.contains('voice') ||
          className.contains('speaking') ||
          className.contains('narration') ||
          className.contains('babbling') ||
          className.contains('chat')) {
        _categoryIndices['Speech']!.add(i);
      }

      // Music related classes
      else if (className.contains('music') ||
          className.contains('instrument') ||
          className.contains('singing') ||
          className.contains('song') ||
          className.contains('melody') ||
          className.contains('tune') ||
          className.contains('beat') ||
          className.contains('guitar') ||
          className.contains('piano') ||
          className.contains('drum') ||
          className.contains('bass') ||
          className.contains('vocal') ||
          className.contains('choir') ||
          className.contains('sine wave') ||
          className.contains('electronic music')) {
        _categoryIndices['Music']!.add(i);
      }

      // Noise related classes
      else if (className.contains('noise') ||
          className.contains('traffic') ||
          className.contains('engine') ||
          className.contains('motor') ||
          className.contains('machine') ||
          className.contains('vehicle') ||
          className.contains('car') ||
          className.contains('alarm') ||
          className.contains('siren') ||
          className.contains('construction') ||
          className.contains('bang') ||
          className.contains('crash') ||
          className.contains('thud') ||
          className.contains('explosion') ||
          className.contains('roar') ||
          className.contains('static')) {
        _categoryIndices['Noise']!.add(i);
      }

      // Nature related classes
      else if (className.contains('water') ||
          className.contains('rain') ||
          className.contains('wind') ||
          className.contains('bird') ||
          className.contains('animal') ||
          className.contains('dog') ||
          className.contains('cat') ||
          className.contains('insect') ||
          className.contains('forest') ||
          className.contains('wave') ||
          className.contains('thunder') ||
          className.contains('rustling') ||
          className.contains('nature') ||
          className.contains('weather')) {
        _categoryIndices['Nature']!.add(i);
      }

      // Quiet related classes
      else if (className.contains('silence') ||
          className.contains('quiet') ||
          className.contains('still') ||
          className.contains('ambient') ||
          className.contains('background')) {
        _categoryIndices['Quiet']!.add(i);
      }
    }

    // Ensure sine wave is in Music category
    int sineWaveIndex = _findClassIndex('sine wave');
    if (sineWaveIndex >= 0 &&
        !_categoryIndices['Music']!.contains(sineWaveIndex)) {
      _categoryIndices['Music']!.add(sineWaveIndex);
    }

    // Print category mappings for debugging
    _categoryIndices.forEach((category, indices) {
      print('Category: $category has ${indices.length} mapped classes');
    });
  }

  int _findClassIndex(String searchTerm) {
    searchTerm = searchTerm.toLowerCase();
    for (int i = 0; i < _classNames.length; i++) {
      if (_classNames[i].toLowerCase().contains(searchTerm)) {
        return i;
      }
    }
    return -1;
  }

  void _printModelInfo() {
    if (_interpreter == null) return;

    // Print input tensor details
    final inputTensors = _interpreter!.getInputTensors();
    print('Input Tensors: ${inputTensors.length}');
    for (var tensor in inputTensors) {
      print(
          '  - Input: ${tensor.name}, Shape: ${tensor.shape}, Type: ${tensor.type}');
    }

    // Print output tensor details
    final outputTensors = _interpreter!.getOutputTensors();
    print('Output Tensors: ${outputTensors.length}');
    for (var tensor in outputTensors) {
      print(
          '  - Output: ${tensor.name}, Shape: ${tensor.shape}, Type: ${tensor.type}');
    }

    // Store the shape of the primary output (scores)
    if (outputTensors.isNotEmpty) {
      _outputScoresShape = outputTensors[0].shape;
    }
  }

  Future<void> _loadClassNames() async {
    try {
      final csvData =
          await rootBundle.loadString('assets/models/yamnet_class_map.csv');
      final lines = csvData.split('\n');
      _classNames = [];

      for (int i = 1; i < lines.length; i++) {
        // Skip header row
        if (lines[i].trim().isNotEmpty) {
          final parts = lines[i].split(',');
          if (parts.length >= 3) {
            _classNames.add(parts[2].replaceAll('"', '').trim());
          }
        }
      }

      if (_classNames.length != 521) {
        print(
            'Warning: Loaded ${_classNames.length} class names, but model expects 521.');
      }
      print('Loaded ${_classNames.length} class names.');
    } catch (e) {
      print('Error loading class names: $e');
      _classNames = List.generate(521, (index) => 'Class_$index');
    }
  }

  Future<Map<String, double>> classifyAudio(Uint8List audioBytes) async {
    if (!_isInitialized || _interpreter == null) {
      throw Exception('YAMNet classifier not initialized');
    }

    try {
      print('=== CLASSIFICATION STARTED ===');
      print('Input audio data length: ${audioBytes.length} bytes');

      // Convert PCM16 bytes to Float32 samples
      final audioSamples = _convertPCM16ToFloat32(audioBytes);

      // Ensure we have the right amount of data
      const int expectedSamples = 15600;
      final processedAudio = Float32List(expectedSamples);

      if (audioSamples.length >= expectedSamples) {
        for (int i = 0; i < expectedSamples; i++) {
          processedAudio[i] =
              audioSamples[audioSamples.length - expectedSamples + i];
        }
      } else {
        for (int i = 0; i < audioSamples.length; i++) {
          processedAudio[i] = audioSamples[i];
        }
      }

      // Normalize audio
      double maxVal = 0.0;
      for (int i = 0; i < processedAudio.length; i++) {
        maxVal = math.max(maxVal, processedAudio[i].abs());
      }
      if (maxVal > 0) {
        for (int i = 0; i < processedAudio.length; i++) {
          processedAudio[i] = processedAudio[i] / maxVal;
        }
        print('Audio normalized (max: ${maxVal.toStringAsFixed(4)})');
      }

      // Run inference
      final input = [processedAudio];
      final output = List.generate(1, (_) => List.filled(521, 0.0));
      _interpreter!.run(input, output);

      final scores = output[0];

      // Enhanced speech detection with more comprehensive class mapping
      final environmentScores = <String, double>{
        'Speech': 0.0,
        'Music': 0.0,
        'Noise': 0.0,
        'Quiet': 0.0,
        'Nature': 0.0,
      };

      // Priority speech detection - collect all speech-related scores
      double maxSpeechScore = 0.0;

      for (int i = 0; i < scores.length && i < _classNames.length; i++) {
        final className = _classNames[i].toLowerCase();
        final score = scores[i];

        // Enhanced speech detection with priority collection
        if (className.contains('speech') ||
            className.contains('conversation') ||
            className.contains('narration') ||
            className.contains('voice') ||
            className.contains('talk') ||
            className.contains('speaking') ||
            className.contains('human voice') ||
            className.contains('child speech') ||
            className.contains('male speech') ||
            className.contains('female speech') ||
            className.contains('podcast') ||
            className.contains('radio') ||
            className.contains('commentary') ||
            className.contains('monologue') ||
            className.contains('dialogue') ||
            className.contains('announcement') ||
            className.contains('lecture') ||
            className.contains('presentation')) {
          // Track the highest speech score
          maxSpeechScore = math.max(maxSpeechScore, score);
          environmentScores['Speech'] =
              math.max(environmentScores['Speech']!, score);
        }

        // Music detection
        else if (className.contains('music') ||
            className.contains('singing') ||
            className.contains('song') ||
            className.contains('melody') ||
            className.contains('guitar') ||
            className.contains('piano') ||
            className.contains('drum') ||
            className.contains('bass') ||
            className.contains('violin') ||
            className.contains('trumpet') ||
            className.contains('musical instrument')) {
          environmentScores['Music'] =
              math.max(environmentScores['Music']!, score);
        }

        // Nature sounds
        else if (className.contains('bird') ||
            className.contains('rain') ||
            className.contains('thunder') ||
            className.contains('wind') ||
            className.contains('water') ||
            className.contains('ocean') ||
            className.contains('nature')) {
          environmentScores['Nature'] =
              math.max(environmentScores['Nature']!, score);
        }

        // Noise/other sounds
        else if (className.contains('noise') ||
            className.contains('cacophony') ||
            className.contains('sound effect') ||
            className.contains('whoosh') ||
            className.contains('traffic') ||
            className.contains('machinery') ||
            className.contains('static') ||
            className.contains('buzz') ||
            className.contains('hiss')) {
          environmentScores['Noise'] =
              math.max(environmentScores['Noise']!, score);
        }
      }

      // PRIORITY: If any speech detected above minimal threshold, prioritize it
      if (maxSpeechScore > 0.01) {
        // Very low threshold for speech priority
        environmentScores['Speech'] = maxSpeechScore;
        print(
            '🚨 Speech priority activated with score: ${(maxSpeechScore * 100).toStringAsFixed(2)}%');
      }

      // Apply smoothing
      for (final category in environmentScores.keys) {
        final currentScore = environmentScores[category]!;
        final previousScore = _lastPrediction[category] ?? 0.0;
        environmentScores[category] = smoothingFactor * currentScore +
            (1 - smoothingFactor) * previousScore;
      }

      _lastPrediction = Map.from(environmentScores);

      // Print top scores for debugging
      print('=== ENVIRONMENT SCORES ===');
      environmentScores.entries.forEach((entry) {
        if (entry.value > 0.01) {
          print('${entry.key}: ${(entry.value * 100).toStringAsFixed(2)}%');
        }
      });

      // Filter and sort results - LOWER THRESHOLD FOR SPEECH
      final filteredResults = <String, double>{};
      for (final entry in environmentScores.entries) {
        // Use very low threshold for speech detection
        final threshold =
            entry.key == 'Speech' ? 0.02 : 0.05; // 2% for speech, 5% for others
        if (entry.value > threshold) {
          filteredResults[entry.key] = entry.value;
        }
      }

      // If no clear environment detected, try to map top raw predictions
      if (filteredResults.isEmpty) {
        // Get top raw prediction
        final indexedScores = <MapEntry<int, double>>[];
        for (int i = 0; i < scores.length; i++) {
          indexedScores.add(MapEntry(i, scores[i]));
        }
        indexedScores.sort((a, b) => b.value.compareTo(a.value));

        print('=== TOP RAW PREDICTIONS (fallback) ===');
        for (int i = 0; i < 5 && i < indexedScores.length; i++) {
          final entry = indexedScores[i];
          final className = entry.key < _classNames.length
              ? _classNames[entry.key]
              : 'Unknown_${entry.key}';
          print(
              '  ${i + 1}: $className (${(entry.value * 100).toStringAsFixed(2)}%)');
        }

        // Try to detect speech from top predictions
        final topPrediction = indexedScores.first;
        final topClassName = topPrediction.key < _classNames.length
            ? _classNames[topPrediction.key].toLowerCase()
            : '';

        // Even more aggressive speech detection
        if (topClassName.contains('speech') ||
            topClassName.contains('voice') ||
            topClassName.contains('talk') ||
            topClassName.contains('human') ||
            topClassName.contains('conversation') ||
            topClassName.contains('narration') ||
            topClassName.contains('monologue') ||
            topClassName.contains('dialogue')) {
          filteredResults['Speech'] = topPrediction.value;
          print('FALLBACK SPEECH DETECTION: $topClassName');
        } else {
          filteredResults['Noise'] = topPrediction.value;
        }
      }

      // Sort by confidence
      final sortedResults = Map.fromEntries(filteredResults.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)));

      print('=== FINAL RESULT ===');
      if (sortedResults.isNotEmpty) {
        final topResult = sortedResults.entries.first;
        print(
            'Environment: ${topResult.key} with confidence ${(topResult.value * 100).toStringAsFixed(2)}%');
      }

      return sortedResults;
    } catch (e, stackTrace) {
      print('Error in YAMNet classification: $e');
      print('Stack trace: $stackTrace');
      return {'Unknown': 0.0};
    }
  }

  // Add this helper method to convert PCM16 to Float32
  Float32List _convertPCM16ToFloat32(Uint8List pcm16Data) {
    final numSamples = pcm16Data.length ~/ 2;
    final float32Data = Float32List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final byteIndex = i * 2;
      final sample = (pcm16Data[byteIndex + 1] << 8) | pcm16Data[byteIndex];

      // Convert from signed 16-bit to signed value
      final signedSample = sample > 32767 ? sample - 65536 : sample;

      // Normalize to [-1.0, +1.0] range
      float32Data[i] = signedSample / 32768.0;
    }

    return float32Data;
  }
}
