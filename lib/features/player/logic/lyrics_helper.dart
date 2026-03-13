import 'dart:async';

import 'package:flutter_lyric/lyrics_reader.dart';
import 'package:flutter_lyric/lyrics_reader_model.dart';

/// Model representing a single lyric line with timing and flags.
class LyricLine {
  final String text;
  final Duration startTime;
  final Duration endTime;
  final bool isChorus;
  final bool isVerse;
  final bool isEmpty;

  LyricLine({
    required this.text,
    required this.startTime,
    required this.endTime,
    this.isChorus = false,
    this.isVerse = false,
    this.isEmpty = false,
  });
}

class LyricsHelper {
  static Future<LyricsReaderModel> prepareLyricsModel(
      String plainLyrics, Duration songDuration) async {
    // Process lyrics using our smart sync algorithm
    final processedLyrics = getSyncedLyrics(plainLyrics, songDuration);

    // Convert to LyricsReaderModel format
    final lrcLines = <String>[];

    for (final lyric in processedLyrics) {
      final minutes = lyric.startTime.inMinutes;
      final seconds = lyric.startTime.inSeconds % 60;
      final centiseconds = (lyric.startTime.inMilliseconds % 1000) ~/ 10;

      final timeTag = '[${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}.'
          '${centiseconds.toString().padLeft(2, '0')}]';

      lrcLines.add('$timeTag${lyric.text}');
    }

    final lrcContent = lrcLines.join('\n');

    // Use the correct LyricsModelBuilder pattern
    final lyricsModel =
        LyricsModelBuilder.create().bindLyricToMain(lrcContent).getModel();

    return lyricsModel;
  }

  static List<LyricLine> getSyncedLyrics(
      String plainLyrics, Duration songDuration) {
    final lines = plainLyrics
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .map((l) => l.trim())
        .toList();

    if (lines.isEmpty) return [];

    final processedLines = <LyricLine>[];
    final totalSeconds = songDuration.inSeconds;

    // Analyze song structure
    final analysisResult = _analyzeSongStructure(lines, totalSeconds);

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final timing = analysisResult[i];

      processedLines.add(LyricLine(
        text: line,
        startTime: Duration(milliseconds: timing['start']),
        endTime: Duration(milliseconds: timing['end']),
        isChorus: timing['isChorus'],
        isVerse: timing['isVerse'],
        isEmpty: line.trim().isEmpty,
      ));
    }

    return processedLines;
  }

  static List<Map<String, dynamic>> _analyzeSongStructure(
      List<String> lines, int totalSeconds) {
    final result = <Map<String, dynamic>>[];
    // Common song structure timing (in percentages)
    final songSections = [
      {
        'name': 'intro',
        'start': 0.0,
        'end': 0.08,
        'speed': 1.2
      }, // Slower intro
      {'name': 'verse1', 'start': 0.08, 'end': 0.25, 'speed': 1.0},
      {
        'name': 'chorus1',
        'start': 0.25,
        'end': 0.40,
        'speed': 0.9
      }, // Faster chorus
      {'name': 'verse2', 'start': 0.40, 'end': 0.55, 'speed': 1.0},
      {'name': 'chorus2', 'start': 0.55, 'end': 0.70, 'speed': 0.9},
      {
        'name': 'bridge',
        'start': 0.70,
        'end': 0.85,
        'speed': 1.1
      }, // Slower bridge
      {
        'name': 'chorus3',
        'start': 0.85,
        'end': 1.0,
        'speed': 0.85
      }, // Final chorus
    ];

    // Detect repeating patterns (chorus detection)
    final chorusLines = _detectChorus(lines);

    // Calculate timing for each line
    int currentSectionIndex = 0;

    for (int i = 0; i < lines.length; i++) {
      // Determine which section we're in
      final sectionProgress = i / lines.length;

      // Find appropriate section
      while (currentSectionIndex < songSections.length - 1 &&
          sectionProgress > (songSections[currentSectionIndex]['end'] as num)) {
        currentSectionIndex++;
      }

      final currentSection = songSections[currentSectionIndex];
      final sectionStart =
          (totalSeconds * (currentSection['start'] as num)).round();
      final sectionEnd =
          (totalSeconds * (currentSection['end'] as num)).round();
      final sectionDuration = sectionEnd - sectionStart;

      // Calculate line timing within section
      final lineProgress = (sectionProgress -
              (currentSection['start'] as num)) /
          ((currentSection['end'] as num) - (currentSection['start'] as num));

      // Adjust timing based on line characteristics
      double speedMultiplier = currentSection['speed'] as double;
      final line = lines[i].toLowerCase();

      // Shorter lines = faster timing
      if (line.length < 20) speedMultiplier *= 0.8;
      if (line.length > 60) speedMultiplier *= 1.3;

      // Detect emotional/climactic lines (usually longer duration)
      if (line.contains('love') ||
          line.contains('heart') ||
          line.contains('forever')) {
        speedMultiplier *= 1.2;
      }

      // Calculate actual timings
      final lineStartMs =
          (sectionStart * 1000 + (lineProgress * sectionDuration * 1000))
              .round();
      final baseDuration =
          (line.length * 80 * speedMultiplier).round(); // ~80ms per character
      final lineEndMs = (lineStartMs + baseDuration)
          .clamp(lineStartMs + 1000, totalSeconds * 1000);

      result.add({
        'start': lineStartMs,
        'end': lineEndMs,
        'isChorus': chorusLines.contains(i),
        'isVerse':
            ((currentSection['name'] as String?)?.contains('verse') ?? false),
        'section': currentSection['name'],
      });
    }

    return result;
  }

  static Set<int> _detectChorus(List<String> lines) {
    final chorusIndices = <int>{};
    final lineCounts = <String, List<int>>{};

    // Count line repetitions
    for (int i = 0; i < lines.length; i++) {
      final cleanLine =
          lines[i].toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
      if (cleanLine.length > 10) {
        // Only consider substantial lines
        lineCounts.putIfAbsent(cleanLine, () => []).add(i);
      }
    }

    // Lines that appear 2+ times are likely chorus
    lineCounts.forEach((line, indices) {
      if (indices.length >= 2) {
        chorusIndices.addAll(indices);
      }
    });

    return chorusIndices;
  }
}
