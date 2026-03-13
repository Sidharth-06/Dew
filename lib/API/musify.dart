/*
 *     Copyright (C) 2025 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dew/API/clients.dart';
import 'package:dew/DB/albums.db.dart';
import 'package:dew/DB/playlists.db.dart';
import 'package:dew/extensions/l10n.dart';
import 'package:dew/main.dart';
import 'package:dew/services/data_manager.dart';
import 'package:dew/services/io_service.dart';
import 'package:dew/services/lyrics_manager.dart';
import 'package:dew/services/proxy_manager.dart';
import 'package:dew/services/settings_manager.dart';
import 'package:dew/utilities/flutter_toast.dart';
import 'package:dew/utilities/formatter.dart';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

// Use ProxyManager's shared client so the global _yt respects the proxy setting.
YoutubeExplode get _yt => ProxyManager().getClientSync();

List globalSongs = [];

List playlists = [...playlistsDB, ...albumsDB];
final userPlaylists = ValueNotifier<List>(
  Hive.box('user').get('playlists', defaultValue: []),
);
final userCustomPlaylists = ValueNotifier<List>(
  Hive.box('user').get('customPlaylists', defaultValue: []),
);
final userPlaylistFolders = ValueNotifier<List>(
  Hive.box('user').get('playlistFolders', defaultValue: []),
);
List userLikedSongsList = Hive.box('user').get('likedSongs', defaultValue: []);
List userLikedPlaylists = Hive.box(
  'user',
).get('likedPlaylists', defaultValue: []);
List userRecentlyPlayed = Hive.box(
  'user',
).get('recentlyPlayedSongs', defaultValue: []);
List userOfflineSongs = Hive.box(
  'userNoBackup',
).get('offlineSongs', defaultValue: []);
List onlinePlaylists = [];

dynamic nextRecommendedSong;

final currentLikedSongsLength = ValueNotifier<int>(userLikedSongsList.length);
final currentLikedPlaylistsLength = ValueNotifier<int>(
  userLikedPlaylists.length,
);
final currentOfflineSongsLength = ValueNotifier<int>(userOfflineSongs.length);
final currentRecentlyPlayedLength = ValueNotifier<int>(
  userRecentlyPlayed.length,
);

// Video-lite mode: cap video resolution to reduce stalls on constrained networks
final videoLiteMode = ValueNotifier<bool>(
  Hive.box('settings').get('videoLiteMode', defaultValue: false),
);

Future<void> setVideoLiteMode(bool enabled) async {
  videoLiteMode.value = enabled;
  await addOrUpdateData('settings', 'videoLiteMode', enabled);
}

final lyrics = ValueNotifier<String?>(null);
String? lastFetchedLyrics;

final _clients = [customAndroidVr, customAndroidSdkless];

Future<List> fetchSongsList(String searchQuery) async {
  try {
    // If not in cache, perform the search
    final List<Video> searchResults = await _yt.search.search(searchQuery);
    final songsList =
        searchResults.map((video) => returnSongLayout(0, video)).toList();

    return songsList;
  } catch (e, stackTrace) {
    logger.log('Error in fetchSongsList', e, stackTrace);
    return [];
  }
}

Future<List> getRecommendedSongs(dynamic externalRecommendations) async {
  try {
    // externalRecommendations can be:
    // - bool / ValueNotifier<bool> to prefer recent-history recs
    // - String seed (e.g., "pop", "trending") to fetch by query
    // - null to fall back to mixed sources

    var preferRecent = false;
    String? seedQuery;

    if (externalRecommendations is ValueNotifier<bool>) {
      preferRecent = externalRecommendations.value;
    } else if (externalRecommendations is bool) {
      preferRecent = externalRecommendations;
    } else if (externalRecommendations is String &&
        externalRecommendations.trim().isNotEmpty) {
      seedQuery = externalRecommendations.trim();
    }

    if (seedQuery != null) {
      // If a seed query is provided, return a capped list of search results.
      final results = await fetchSongsList(seedQuery);
      return results.take(15).toList();
    }

    if (preferRecent && userRecentlyPlayed.isNotEmpty) {
      return await _getRecommendationsFromRecentlyPlayed();
    }

    return await _getRecommendationsFromMixedSources();
  } catch (e, stackTrace) {
    logger.log('Error in getRecommendedSongs', e, stackTrace);
    return [];
  }
}

Future<List> _getRecommendationsFromRecentlyPlayed() async {
  final recent = userRecentlyPlayed.take(3).toList();

  final futures = recent.map((songData) async {
    try {
      final song = await _yt.videos.get(songData['ytid']);
      final relatedSongs = await _yt.videos.getRelatedVideos(song) ?? [];
      return relatedSongs.take(3).map((s) => returnSongLayout(0, s)).toList();
    } catch (e, stackTrace) {
      logger.log(
        'Error getting related videos for ${songData['ytid']}',
        e,
        stackTrace,
      );
      return <Map>[];
    }
  }).toList();

  final results = await Future.wait(futures);
  // Limit to 15 items max for performance
  final playlistSongs = results.expand((list) => list).take(15).toList()
    ..shuffle();
  return playlistSongs;
}

Future<List> _getRecommendationsFromMixedSources() async {
  final playlistSongs = [...userLikedSongsList, ...userRecentlyPlayed];

  if (globalSongs.isEmpty) {
    const playlistId = 'PLgzTt0k8mXzEk586ze4BjvDXR7c-TUSnx';
    globalSongs = await getSongsFromPlaylist(playlistId);
  }
  playlistSongs.addAll(globalSongs.take(10));

  if (userCustomPlaylists.value.isNotEmpty) {
    for (final userPlaylist in userCustomPlaylists.value) {
      final _list = (userPlaylist['list'] as List)..shuffle();
      playlistSongs.addAll(_list.take(5));
    }
  }

  return _deduplicateAndShuffle(playlistSongs);
}

List _deduplicateAndShuffle(List playlistSongs) {
  final seenYtIds = <String>{};
  final uniqueSongs = <Map>[];

  playlistSongs.shuffle();

  for (final song in playlistSongs) {
    if (song['ytid'] != null && seenYtIds.add(song['ytid'])) {
      uniqueSongs.add(song);
      // Early exit when we have enough songs
      if (uniqueSongs.length >= 15) break;
    }
  }

  return uniqueSongs;
}

Future<List<dynamic>> getUserPlaylists() async {
  final playlistsByUser = [];
  for (final playlistID in userPlaylists.value) {
    try {
      final plist = await _yt.playlists.get(playlistID);
      playlistsByUser.add({
        'ytid': plist.id.toString(),
        'title': plist.title,
        'image': null,
        'source': 'user-youtube',
        'list': [],
      });
    } catch (e, stackTrace) {
      playlistsByUser.add({
        'ytid': playlistID.toString(),
        'title': 'Failed playlist',
        'image': null,
        'source': 'user-youtube',
        'list': [],
      });
      logger.log('Error occurred while fetching the playlist:', e, stackTrace);
    }
  }
  return playlistsByUser;
}

Future<String> addUserPlaylist(String input, BuildContext context) async {
  String? playlistId = input;

  if (input.startsWith('http://') || input.startsWith('https://')) {
    playlistId = extractYoutubePlaylistId(input);

    if (playlistId == null) {
      return '${context.l10n!.notYTlist}!';
    }
  }

  try {
    final _playlist = await _yt.playlists.get(playlistId);

    if (playlistExistsAnywhere(playlistId)) {
      return '${context.l10n!.playlistAlreadyExists}!';
    }

    if (_playlist.title.isEmpty) {
      return '${context.l10n!.invalidYouTubePlaylist}!';
    }

    userPlaylists.value = [...userPlaylists.value, playlistId];
    await addOrUpdateData('user', 'playlists', userPlaylists.value);
    return '${context.l10n!.addedSuccess}!';
  } catch (e, stackTrace) {
    logger.log('Error adding user playlist', e, stackTrace);
    return '${context.l10n!.error}: $e';
  }
}

String createCustomPlaylist(
  String playlistName,
  String? image,
  BuildContext context,
) {
  final creationTime = DateTime.now().millisecondsSinceEpoch;
  final customPlaylist = {
    'ytid': 'customId-$creationTime',
    'title': playlistName,
    'source': 'user-created',
    if (image != null) 'image': image,
    'list': [],
    'createdAt': creationTime,
  };
  userCustomPlaylists.value = [...userCustomPlaylists.value, customPlaylist];
  addOrUpdateData('user', 'customPlaylists', userCustomPlaylists.value);
  return '${context.l10n!.addedSuccess}!';
}

String addSongInCustomPlaylist(
  BuildContext context,
  String playlistName,
  Map song, {
  int? indexToInsert,
}) {
  final customPlaylist = userCustomPlaylists.value.firstWhere(
    (playlist) => playlist['title'] == playlistName,
    orElse: () => null,
  );

  if (customPlaylist != null) {
    final List<dynamic> playlistSongs = customPlaylist['list'];
    if (playlistSongs.any(
      (playlistElement) => playlistElement['ytid'] == song['ytid'],
    )) {
      return context.l10n!.songAlreadyInPlaylist;
    }
    indexToInsert != null
        ? playlistSongs.insert(indexToInsert, song)
        : playlistSongs.add(song);
    addOrUpdateData('user', 'customPlaylists', userCustomPlaylists.value);
    return context.l10n!.songAdded;
  } else {
    logger.log('Custom playlist not found: $playlistName', null, null);
    return context.l10n!.error;
  }
}

bool removeSongFromPlaylist(
  Map playlist,
  Map songToRemove, {
  int? removeOneAtIndex,
}) {
  try {
    if (playlist['list'] == null) return false;

    final playlistSongs = List<dynamic>.from(playlist['list']);
    if (removeOneAtIndex != null) {
      if (removeOneAtIndex < 0 || removeOneAtIndex >= playlistSongs.length) {
        return false;
      }
      playlistSongs.removeAt(removeOneAtIndex);
    } else {
      final initialLength = playlistSongs.length;
      playlistSongs.removeWhere((song) => song['ytid'] == songToRemove['ytid']);
      if (playlistSongs.length == initialLength) return false;
    }

    playlist['list'] = playlistSongs;

    try {
      if (playlist['source'] == 'user-created') {
        addOrUpdateData('user', 'customPlaylists', userCustomPlaylists.value);
      } else {
        addOrUpdateData('user', 'playlists', userPlaylists.value);
      }
    } catch (e, stackTrace) {
      logger.log('Error saving playlist changes', e, stackTrace);
      return false;
    }

    return true;
  } catch (e, stackTrace) {
    logger.log('Error while removing song from playlist: ', e, stackTrace);
    return false;
  }
}

void removeUserPlaylist(String playlistId) {
  final updatedPlaylists = List.from(userPlaylists.value)..remove(playlistId);
  userPlaylists.value = updatedPlaylists;
  addOrUpdateData('user', 'playlists', userPlaylists.value);
}

void removeUserCustomPlaylist(dynamic playlist) {
  final updatedPlaylists = List.from(userCustomPlaylists.value)
    ..remove(playlist);
  userCustomPlaylists.value = updatedPlaylists;
  addOrUpdateData('user', 'customPlaylists', userCustomPlaylists.value);
}

// Playlist Folders Management Functions

String createPlaylistFolder(String folderName, [BuildContext? context]) {
  if (folderName.trim().isEmpty) {
    return context?.l10n?.enterFolderName ?? 'Please enter a folder name';
  }

  // Check if folder already exists
  final exists = userPlaylistFolders.value.any(
    (folder) =>
        folder['name'].toString().toLowerCase() ==
        folderName.trim().toLowerCase(),
  );

  if (exists) {
    return context?.l10n?.folderAlreadyExists ?? 'Folder already exists';
  }

  final newFolder = {
    'id': DateTime.now().millisecondsSinceEpoch.toString(),
    'name': folderName.trim(),
    'playlists': <Map>[],
    'createdAt': DateTime.now().millisecondsSinceEpoch,
  };

  userPlaylistFolders.value = [...userPlaylistFolders.value, newFolder];
  addOrUpdateData('user', 'playlistFolders', userPlaylistFolders.value);
  return context?.l10n?.addedSuccess ?? 'Added successfully';
}

String movePlaylistToFolder(
  Map playlist,
  String? folderId,
  BuildContext context,
) {
  try {
    final updatedFolders = List<Map>.from(userPlaylistFolders.value);
    final updatedCustomPlaylists = List<Map>.from(userCustomPlaylists.value);
    final updatedYoutubePlaylists = List.from(userPlaylists.value);

    // Remove playlist from any existing folder
    for (final folder in updatedFolders) {
      final folderPlaylists = List<Map>.from(
        folder['playlists'] ?? [],
      )..removeWhere((p) => p['ytid'] != null && p['ytid'] == playlist['ytid']);
      folder['playlists'] = folderPlaylists;
    }

    // Remove from main playlists if moving to a folder
    if (folderId != null) {
      final targetFolder = updatedFolders.firstWhere(
        (folder) => folder['id'] == folderId,
        orElse: () => {},
      );

      if (targetFolder.isNotEmpty) {
        final folderPlaylists = List<Map>.from(targetFolder['playlists'] ?? [])
          ..add(playlist);
        targetFolder['playlists'] = folderPlaylists;

        // Remove from main list based on playlist type
        if (playlist['source'] == 'user-created') {
          updatedCustomPlaylists.removeWhere(
            (p) => p['ytid'] == playlist['ytid'],
          );
        } else if (playlist['source'] == 'user-youtube') {
          updatedYoutubePlaylists.removeWhere((p) => p == playlist['ytid']);
        }
      }
    } else {
      // Moving out of folder to main list
      if (playlist['source'] == 'user-created') {
        if (!updatedCustomPlaylists.any((p) => p['ytid'] == playlist['ytid'])) {
          updatedCustomPlaylists.add(playlist);
        }
      } else if (playlist['source'] == 'user-youtube') {
        if (!updatedYoutubePlaylists.contains(playlist['ytid'])) {
          updatedYoutubePlaylists.add(playlist['ytid']);
        }
      }
    }

    userPlaylistFolders.value = updatedFolders;
    userCustomPlaylists.value = updatedCustomPlaylists;
    userPlaylists.value = updatedYoutubePlaylists;

    addOrUpdateData('user', 'playlistFolders', userPlaylistFolders.value);
    addOrUpdateData('user', 'customPlaylists', userCustomPlaylists.value);
    addOrUpdateData('user', 'playlists', userPlaylists.value);

    return '${context.l10n!.addedSuccess}!';
  } catch (e, stackTrace) {
    logger.log('Error moving playlist to folder', e, stackTrace);
    return context.l10n!.error;
  }
}

String deletePlaylistFolder(String folderId, [BuildContext? context]) {
  try {
    final updatedFolders = List<Map>.from(userPlaylistFolders.value);
    final folderToDelete = updatedFolders.firstWhere(
      (folder) => folder['id'] == folderId,
      orElse: () => {},
    );

    if (folderToDelete.isNotEmpty) {
      // Move all playlists from folder back to main list
      final folderPlaylists = List<Map>.from(folderToDelete['playlists'] ?? []);
      final updatedCustomPlaylists = List<Map>.from(userCustomPlaylists.value);
      final updatedYoutubePlaylists = List.from(userPlaylists.value);

      for (final playlist in folderPlaylists) {
        if (playlist['source'] == 'user-created') {
          if (playlist['ytid'] != null &&
              !updatedCustomPlaylists.any(
                (p) => p['ytid'] == playlist['ytid'],
              )) {
            updatedCustomPlaylists.add(playlist);
          }
        } else if (playlist['source'] == 'user-youtube') {
          if (playlist['ytid'] != null &&
              !updatedYoutubePlaylists.contains(playlist['ytid'])) {
            updatedYoutubePlaylists.add(playlist['ytid']);
          }
        }
      }

      // Remove the folder
      updatedFolders.removeWhere((folder) => folder['id'] == folderId);

      userPlaylistFolders.value = updatedFolders;
      userCustomPlaylists.value = updatedCustomPlaylists;
      userPlaylists.value = updatedYoutubePlaylists;

      addOrUpdateData('user', 'playlistFolders', userPlaylistFolders.value);
      addOrUpdateData('user', 'customPlaylists', userCustomPlaylists.value);
      addOrUpdateData('user', 'playlists', userPlaylists.value);

      return context?.l10n?.folderDeleted ?? 'Folder deleted successfully';
    }
    return context?.l10n?.error ?? 'Error';
  } catch (e, stackTrace) {
    logger.log('Error deleting playlist folder', e, stackTrace);
    return context?.l10n?.error ?? 'Error';
  }
}

List<Map> getPlaylistsInFolder(String folderId) {
  try {
    final folder = userPlaylistFolders.value.firstWhere(
      (folder) => folder['id'] == folderId,
      orElse: () => {},
    );
    return List<Map>.from(folder['playlists'] ?? []);
  } catch (e) {
    return [];
  }
}

List<Map> getPlaylistsNotInFolders() {
  // Get all playlist IDs that are in folders
  final playlistsInFolders = <String>{};
  for (final folder in userPlaylistFolders.value) {
    final folderPlaylists = folder['playlists'] as List<dynamic>? ?? [];
    for (final playlist in folderPlaylists) {
      if (playlist['ytid'] != null) {
        playlistsInFolders.add(playlist['ytid']);
      }
    }
  }

  // Filter out playlists that are in folders
  return userCustomPlaylists.value
      .where((playlist) {
        final playlistId = playlist['ytid'];
        return playlistId == null || !playlistsInFolders.contains(playlistId);
      })
      .toList()
      .cast<Map>();
}

Future<void> updateSongLikeStatus(dynamic songId, bool add) async {
  try {
    if (add) {
      if (!userLikedSongsList.any((song) => song['ytid'] == songId)) {
        final songDetails = await getSongDetails(
          userLikedSongsList.length,
          songId,
        );
        userLikedSongsList.add(songDetails);
      }
    } else {
      userLikedSongsList.removeWhere((song) => song['ytid'] == songId);
    }

    currentLikedSongsLength.value = userLikedSongsList.length;
    await addOrUpdateData('user', 'likedSongs', userLikedSongsList);
  } catch (e, stackTrace) {
    logger.log('Error updating song like status', e, stackTrace);
  }
}

void moveLikedSong(int oldIndex, int newIndex) {
  final _song = userLikedSongsList[oldIndex];
  userLikedSongsList
    ..removeAt(oldIndex)
    ..insert(newIndex, _song);
  currentLikedSongsLength.value = userLikedSongsList.length;
  addOrUpdateData('user', 'likedSongs', userLikedSongsList);
}

Future<void> updatePlaylistLikeStatus(String playlistId, bool add) async {
  try {
    if (add) {
      if (!userLikedPlaylists.any(
        (playlist) => playlist['ytid'] == playlistId,
      )) {
        final playlist = playlists.firstWhere(
          (playlist) => playlist['ytid'] == playlistId,
          orElse: () => <String, dynamic>{},
        );

        if (playlist.isNotEmpty) {
          userLikedPlaylists.add(playlist);
        } else {
          final playlistInfo = await getPlaylistInfoForWidget(playlistId);
          if (playlistInfo != null) {
            userLikedPlaylists.add(playlistInfo);
          }
        }
      }
    } else {
      userLikedPlaylists.removeWhere(
        (playlist) => playlist['ytid'] == playlistId,
      );
    }

    currentLikedPlaylistsLength.value = userLikedPlaylists.length;
    await addOrUpdateData('user', 'likedPlaylists', userLikedPlaylists);
  } catch (e, stackTrace) {
    logger.log('Error updating playlist like status: ', e, stackTrace);
  }
}

bool isSongAlreadyLiked(songIdToCheck) =>
    userLikedSongsList.any((song) => song['ytid'] == songIdToCheck);

bool isPlaylistAlreadyLiked(playlistIdToCheck) =>
    userLikedPlaylists.any((playlist) => playlist['ytid'] == playlistIdToCheck);

bool isSongAlreadyOffline(songIdToCheck) =>
    userOfflineSongs.any((song) => song['ytid'] == songIdToCheck);

Future<List> getPlaylists({
  String? query,
  int? playlistsNum,
  bool onlyLiked = false,
  String type = 'all',
}) async {
  // Early exit if there are no playlists to process.
  if (playlists.isEmpty || (playlistsNum == null && query == null)) {
    return [];
  }

  // If only liked playlists should be returned, ignore other parameters.
  if (onlyLiked) {
    if (playlistsNum != null) {
      return userLikedPlaylists.take(playlistsNum).toList();
    }
    return userLikedPlaylists;
  }

  // If a query is provided (without a limit), filter playlists based on the query and type,
  // and augment with online search results.
  if (query != null && playlistsNum == null) {
    final lowercaseQuery = query.toLowerCase();
    final filteredPlaylists = playlists.where((playlist) {
      final title = playlist['title'].toLowerCase();
      final matchesQuery = title.contains(lowercaseQuery);
      final matchesType = type == 'all' ||
          (type == 'album' && playlist['isAlbum'] == true) ||
          (type == 'playlist' && playlist['isAlbum'] != true);
      return matchesQuery && matchesType;
    }).toList();

    final searchTerm = type == 'album' ? '$query album' : query;

    late final Iterable searchResultsIterable;
    try {
      searchResultsIterable = await _yt.search.searchContent(
        searchTerm,
        filter: TypeFilters.playlist,
      );
    } catch (e, st) {
      logger.log('Error while searching online songs:$e', e, st);
      // Attempt proxy fallback if enabled
      if (useProxy.value) {
        final proxyYt = await ProxyManager().getYoutubeExplodeClient();
        if (proxyYt != null) {
          try {
            searchResultsIterable = await proxyYt.search.searchContent(
              searchTerm,
              filter: TypeFilters.playlist,
            );
          } catch (e2, st2) {
            logger.log('Proxy search failed:$e2', e2, st2);
            searchResultsIterable = <dynamic>[];
          } finally {
            try {
              proxyYt.close();
            } catch (_) {}
          }
        } else {
          searchResultsIterable = <dynamic>[];
        }
      } else {
        searchResultsIterable = <dynamic>[];
      }
    }

    // Avoid duplicate online playlists.
    final existingYtIds =
        onlinePlaylists.map((p) => p['ytid'] as String).toSet();

    final newPlaylists = searchResultsIterable
        .whereType<SearchPlaylist>()
        .map((playlist) {
          final playlistMap = {
            'ytid': playlist.id.toString(),
            'title': playlist.title,
            'source': 'youtube',
            'list': [],
          };
          if (!existingYtIds.contains(playlistMap['ytid'])) {
            existingYtIds.add(playlistMap['ytid'].toString());
            return playlistMap;
          }
          return null;
        })
        .whereType<Map<String, dynamic>>()
        .toList();
    onlinePlaylists.addAll(newPlaylists);

    // Merge online playlists that match the query.
    filteredPlaylists.addAll(
      onlinePlaylists.where(
        (p) => p['title'].toLowerCase().contains(lowercaseQuery),
      ),
    );
    return filteredPlaylists;
  }

  // If a specific number of playlists is requested (without a query),
  // return a shuffled subset of suggested playlists.
  if (playlistsNum != null && query == null) {
    final suggestedPlaylists = List<Map>.from(playlists)..shuffle();
    return suggestedPlaylists.take(playlistsNum).toList();
  }

  // If a specific type is requested, filter accordingly.
  if (type != 'all') {
    return playlists.where((playlist) {
      return type == 'album'
          ? playlist['isAlbum'] == true
          : playlist['isAlbum'] != true;
    }).toList();
  }

  // Default to returning all playlists.
  return playlists;
}

Future<List<String>> getSearchSuggestions(
  String query, {
  required int playlistsNum,
}) async {
  // Custom implementation:

  // const baseUrl = 'https://suggestqueries.google.com/complete/search';
  // final parameters = {
  //   'client': 'firefox',
  //   'ds': 'yt',
  //   'q': query,
  // };

  // final uri = Uri.parse(baseUrl).replace(queryParameters: parameters);

  // try {
  //   final response = await http.get(
  //     uri,
  //     headers: {
  //       'User-Agent':
  //           'Mozilla/5.0 (Windows NT 10.0; rv:96.0) Gecko/20100101 Firefox/96.0',
  //     },
  //   );

  //   if (response.statusCode == 200) {
  //     final suggestions = jsonDecode(response.body)[1] as List<dynamic>;
  //     final suggestionStrings = suggestions.cast<String>().toList();
  //     return suggestionStrings;
  //   }
  // } catch (e, stackTrace) {
  //   logger.log('Error in getSearchSuggestions:$e\n$stackTrace');
  // }

  // Built-in implementation:

  final suggestions = await _yt.search.getQuerySuggestions(query);

  return suggestions;
}

Future<List<Map<String, int>>> getSkipSegments(String id) async {
  try {
    final res = await http.get(
      Uri(
        scheme: 'https',
        host: 'sponsor.ajay.app',
        path: '/api/skipSegments',
        queryParameters: {
          'videoID': id,
          'category': [
            'sponsor',
            'selfpromo',
            'interaction',
            'intro',
            'outro',
            'music_offtopic',
          ],
          'actionType': 'skip',
        },
      ),
    );
    if (res.body != 'Not Found') {
      final data = jsonDecode(res.body);
      final segments = data.map((obj) {
        return Map.castFrom<String, dynamic, String, int>({
          'start': obj['segment'].first.toInt(),
          'end': obj['segment'].last.toInt(),
        });
      }).toList();
      return List.castFrom<dynamic, Map<String, int>>(segments);
    } else {
      return [];
    }
  } catch (e, stack) {
    logger.log('Error in getSkipSegments', e, stack);
    return [];
  }
}

Future<void> getSimilarSong(String songYtId) async {
  try {
    final song = await _yt.videos.get(songYtId);
    final relatedSongs = await _yt.videos.getRelatedVideos(song) ?? [];

    if (relatedSongs.isNotEmpty) {
      nextRecommendedSong = returnSongLayout(0, relatedSongs[0]);
    } else {
      logger.log('No related songs found for $songYtId', null, null);
    }
  } catch (e, stackTrace) {
    logger.log('Error while fetching next similar song:', e, stackTrace);
  }
}

Future<List> getSongsFromPlaylist(
  dynamic playlistId, {
  String? playlistImage,
}) async {
  final songList = await getData('cache', 'playlistSongs$playlistId') ?? [];

  if (songList.isEmpty) {
    await for (final song in _yt.playlists.getVideos(playlistId)) {
      songList.add(
        returnSongLayout(songList.length, song, playlistImage: playlistImage),
      );
    }

    await addOrUpdateData('cache', 'playlistSongs$playlistId', songList);
  }

  return songList;
}

Future updatePlaylistList(BuildContext context, String playlistId) async {
  final index = findPlaylistIndexByYtId(playlistId);
  if (index != -1) {
    final songList = [];
    await for (final song in _yt.playlists.getVideos(playlistId)) {
      songList.add(returnSongLayout(songList.length, song));
    }

    playlists[index]['list'] = songList;
    await addOrUpdateData('cache', 'playlistSongs$playlistId', songList);
    showToast(context, context.l10n!.playlistUpdated);
  }
  return playlists[index];
}

int findPlaylistIndexByYtId(String ytid) {
  for (var i = 0; i < playlists.length; i++) {
    if (playlists[i]['ytid'] == ytid) {
      return i;
    }
  }
  return -1;
}

Future<Map?> getPlaylistInfoForWidget(
  dynamic id, {
  bool isArtist = false,
}) async {
  if (isArtist) {
    try {
      return {'title': id, 'list': await fetchSongsList(id)};
    } catch (e, stackTrace) {
      logger.log('Error fetching artist songs for $id', e, stackTrace);
      return {'title': id, 'list': []};
    }
  }

  Map? playlist;

  try {
    // Check in custom playlists first
    if (id != null && id.toString().startsWith('customId-')) {
      playlist = userCustomPlaylists.value.firstWhere(
        (p) => p['ytid'] == id,
        orElse: () => null,
      );
      if (playlist != null) {
        return playlist;
      }
    }

    // Check in existing playlists.

    playlist = playlists.firstWhere((p) => p['ytid'] == id, orElse: () => null);

    // Check in user playlists if not found.
    if (playlist == null) {
      final userPl = await getUserPlaylists();
      playlist = userPl.firstWhere((p) => p['ytid'] == id, orElse: () => null);
    }

    // Check in cached online playlists if still not found.
    playlist ??= onlinePlaylists.firstWhere(
      (p) => p['ytid'] == id,
      orElse: () => null,
    );

    // If still not found, attempt to fetch playlist info.
    if (playlist == null) {
      try {
        final ytPlaylist = await _yt.playlists.get(id);
        playlist = {
          'ytid': ytPlaylist.id.toString(),
          'title': ytPlaylist.title,
          'image': null,
          'source': 'user-youtube',
          'list': [],
        };
        onlinePlaylists.add(playlist);
      } catch (e, stackTrace) {
        logger.log('Failed to fetch playlist info for id $id', e, stackTrace);
        return null;
      }
    }

    // If the playlist exists but its song list is empty, fetch and cache the songs.
    if (playlist['list'] == null ||
        (playlist['list'] is List && (playlist['list'] as List).isEmpty)) {
      try {
        final playlistImage =
            playlist['isAlbum'] == true ? playlist['image'] : null;
        playlist['list'] = await getSongsFromPlaylist(
          playlist['ytid'],
          playlistImage: playlistImage,
        );
        if (!playlists.contains(playlist)) {
          playlists.add(playlist);
        }
      } catch (e, stackTrace) {
        logger.log(
          'Error fetching songs for playlist ${playlist['ytid']}',
          e,
          stackTrace,
        );
        playlist['list'] = [];
      }
    }

    return playlist;
  } catch (e, stackTrace) {
    logger.log(
      'Unexpected error in getPlaylistInfoForWidget for id $id',
      e,
      stackTrace,
    );
    return null;
  }
}

Future<AudioOnlyStreamInfo?> getSongManifest(String? songId) async {
  try {
    if (songId == null || songId.isEmpty) {
      logger.log('getSongManifest: songId is null or empty', null, null);
      return null;
    }

    StreamManifest? manifest;
    if (useProxy.value) {
      manifest = await ProxyManager()
          .getSongManifest(songId)
          .timeout(const Duration(seconds: 12));
    } else {
      manifest = await _yt.videos.streams
          .getManifest(songId, ytClients: _clients)
          .timeout(const Duration(seconds: 12));
    }
    final audioStream = manifest?.audioOnly;
    if (audioStream == null || audioStream.isEmpty) {
      logger.log('getSongManifest: no audio streams for $songId', null, null);
      return null;
    }
    return audioStream.withHighestBitrate();
  } on TimeoutException catch (_) {
    logger.log('getSongManifest request timed out for $songId', null, null);
    return null;
  } catch (e, stackTrace) {
    logger.log('Error while getting song streaming manifest', e, stackTrace);
    return null;
  }
}

Future<Map<String, dynamic>?> getVideoStreamUrl(
  String songId, {
  int targetQuality = 1080,
}) async {
  try {
    const _cacheDuration = Duration(hours: 3);
    // Cap at targetQuality, but also respect videoLiteMode
    // Allow up to 2160p (4K) for best quality; videoLiteMode caps at 720p to save bandwidth
    final globalMax = videoLiteMode.value ? 720 : 2160;
    final maxRes = targetQuality < globalMax ? targetQuality : globalMax;
    // Include player style in cache key so audio and video modes have separate cached URLs
    final playerStyle = playerStyleSetting.value;
    final cacheKey = 'video_${songId}_${maxRes}_${playerStyle}_url';

    // Try cached stream info first to avoid repeated manifest fetches that can stutter playback.
    final cachedData = await getData(
      'cache',
      cacheKey,
      cachingDuration: _cacheDuration,
    );
    if (cachedData is Map<String, dynamic> && cachedData.containsKey('url')) {
      return cachedData;
    }

    StreamManifest? manifest;
    if (useProxy.value) {
      manifest = await ProxyManager()
          .getSongManifest(songId)
          .timeout(const Duration(seconds: 12));
    } else {
      manifest = await _yt.videos.streams
          .getManifest(songId, ytClients: _clients)
          .timeout(const Duration(seconds: 12));
    }

    if (manifest == null) return null;

    // In video-style mode, we want muxed streams (audio+video) so the video carries audio.
    // In other modes, prefer video-only to save bandwidth since audio comes from audioHandler.
    // Filter to mp4 when possible to improve decoder stability on mobile.
    final videoOnly =
        manifest.videoOnly.where((s) => s.container.name == 'mp4').toList()
          ..addAll(
            manifest.videoOnly.where((s) => s.container.name != 'mp4'),
          ); // keep others as fallback

    final muxed = manifest.muxed
        .where((s) => s.container.name == 'mp4')
        .toList()
      ..addAll(manifest.muxed.where((s) => s.container.name != 'mp4'));

    // Log available streams for debugging
    final videoResolutions =
        videoOnly.map((s) => '${s.videoResolution.height}p').toSet();
    final muxedResolutions =
        muxed.map((s) => '${s.videoResolution.height}p').toSet();
    logger.log(
      'Video streams available: ${videoResolutions.join(', ')}',
      null,
      null,
    );
    logger.log(
      'Muxed streams available: ${muxedResolutions.join(', ')}',
      null,
      null,
    );

    if (videoOnly.isEmpty && muxed.isEmpty) return null;

    // Pick best quality up to maxRes to avoid 4K bandwidth while improving clarity.
    Map<String, dynamic>? _pickBest<T extends StreamInfo>(
      List<T> streams,
      int Function(T) heightGetter,
    ) {
      if (streams.isEmpty) return null;

      // Sort by bitrate descending, then resolution descending for stability.
      streams.sort((a, b) {
        final br = b.bitrate.compareTo(a.bitrate);
        if (br != 0) return br;
        return heightGetter(b).compareTo(heightGetter(a));
      });

      // Choose highest bitrate stream that is <=maxRes if available, else the top stream.
      final capped = streams.firstWhere(
        (s) => heightGetter(s) <= maxRes,
        orElse: () => streams.first,
      );
      return {'url': capped.url.toString(), 'res': heightGetter(capped)};
    }

    final videoPick = _pickBest<VideoOnlyStreamInfo>(
      videoOnly,
      (s) => s.videoResolution.height,
    );
    final muxedPick = _pickBest<MuxedStreamInfo>(
      muxed,
      (s) => s.videoResolution.height,
    );

    // In video mode, prefer high-quality video-only streams (1080p+) with audio handler unmuted.
    // In audio mode, prefer video-only to save bandwidth since audio comes from audioHandler.
    // Video mode strategy: Use video-only for best quality, audio handler provides audio track.
    Map<String, dynamic>? chosen;
    if (playerStyleSetting.value == 'video') {
      // Video mode: Prefer video-only for maximum quality (1080p+)
      // Audio handler will stay unmuted to provide the audio track alongside high-quality video
      chosen = videoPick ?? muxedPick;
      if (videoPick != null) {
        logger.log(
          'Video mode: using video-only stream (audio handler will play audio)',
          null,
          null,
        );
      } else if (muxedPick != null) {
        logger.log(
          'Video mode: no high-quality video available, using muxed stream',
          null,
          null,
        );
      }
    } else {
      // Audio mode: prefer video-only to save bandwidth (audio from audioHandler)
      chosen = videoPick ?? muxedPick;
    }

    final url = chosen?['url'] as String?;
    final selectedRes = chosen?['res'] as int?;

    // Determine if this stream has embedded audio (muxed) or is video-only
    final hasMuxedAudio = chosen == muxedPick;

    if (url != null && selectedRes != null) {
      logger.log('Video stream selected: ${selectedRes}p (maxRes: $maxRes)',
          null, null);
      logger.log('Has embedded audio: $hasMuxedAudio', null, null);
    }

    // Cache and return the complete map with URL and audio info
    if (url != null && url.isNotEmpty) {
      final result = {
        'url': url,
        'res': selectedRes ?? 0,
        'hasMuxedAudio': hasMuxedAudio,
      };
      await addOrUpdateData('cache', cacheKey, result);
      return result;
    }
    return null;
  } on TimeoutException catch (_) {
    logger.log('getVideoStreamUrl request timed out for $songId', null, null);
    return null;
  } catch (e, stackTrace) {
    logger.log('Error while getting video stream url', e, stackTrace);
    return null;
  }
}

Future<String?> getSong(String songId, bool? isLive,
    {bool forceRefresh = false}) async {
  try {
    const _cacheDuration = Duration(hours: 3);
    final cacheKey = 'audio_${songId}_url';

    if (!forceRefresh) {
      final cachedUrl = await getData(
        'cache',
        cacheKey,
        cachingDuration: _cacheDuration,
      );

      if (cachedUrl != null && cachedUrl is String && cachedUrl.isNotEmpty) {
        // Only validate with HEAD if cache is older than 1 hour
        final cacheBox = await Hive.openBox('cache');
        final cacheDate = cacheBox.get('${cacheKey}_date');
        final now = DateTime.now();
        final isOld = cacheDate is DateTime &&
            now.difference(cacheDate) > const Duration(hours: 1);
        var valid = true;
        if (isOld) {
          try {
            final response = await http.head(Uri.parse(cachedUrl));
            if (response.statusCode < 200 || response.statusCode >= 300) {
              valid = false;
            }
          } catch (_) {
            valid = false;
          }
          if (!valid) {
            await deleteData('cache', cacheKey);
            await deleteData('cache', '${cacheKey}_date');
          }
        }
        if (valid) {
          unawaited(updateRecentlyPlayed(songId));
          return cachedUrl;
        }
      }
    }

    // Get fresh URL
    StreamManifest? manifest;
    if (useProxy.value) {
      manifest = await ProxyManager()
          .getSongManifest(songId)
          .timeout(const Duration(seconds: 12));
    } else {
      manifest = await _yt.videos.streams
          .getManifest(songId, ytClients: _clients)
          .timeout(const Duration(seconds: 12));
    }
    final audioStreams = manifest?.audioOnly;
    if (audioStreams == null || audioStreams.isEmpty) {
      logger.log('getSong: no audio streams for $songId', null, null);
      return null;
    }

    final selectedStream = selectAudioQuality(audioStreams.sortByBitrate());
    final url = selectedStream.url.toString();

    await addOrUpdateData('cache', cacheKey, url);

    unawaited(updateRecentlyPlayed(songId));
    return url;
  } on TimeoutException catch (_) {
    logger.log('getSong request timed out for $songId', null, null);
    return null;
  } catch (e, stackTrace) {
    logger.log('Error in getSong for songId $songId:', e, stackTrace);
    return null;
  }
}

AudioStreamInfo selectAudioQuality(List<AudioStreamInfo> availableSources) {
  final qualitySetting = audioQualitySetting.value;

  if (qualitySetting == 'low') {
    return availableSources.last;
  } else if (qualitySetting == 'medium') {
    return availableSources[availableSources.length ~/ 2];
  }

  return availableSources.withHighestBitrate();
}

Future<Map<String, dynamic>> getSongDetails(
  int songIndex,
  String songId,
) async {
  try {
    final song = await _yt.videos.get(songId);
    return returnSongLayout(songIndex, song);
  } catch (e, stackTrace) {
    logger.log('Error while getting song details', e, stackTrace);
    rethrow;
  }
}

Future<String?> getSongLyrics(String? artist, String title) async {
  if (artist == null) return null;
  if (lastFetchedLyrics != '$artist - $title') {
    lyrics.value = null;
    var _lyrics = await LyricsManager().fetchLyrics(artist, title);
    if (_lyrics != null) {
      _lyrics = _lyrics.replaceAll(RegExp(r'\n{2}'), '\n');
      _lyrics = _lyrics.replaceAll(RegExp(r'\n{4}'), '\n\n');
      lyrics.value = _lyrics;
    } else {
      return null;
    }

    lastFetchedLyrics = '$artist - $title';
    return _lyrics;
  }

  return lyrics.value;
}

Future<bool> makeSongOffline(dynamic song, {bool fromPlaylist = false}) async {
  try {
    final String? ytid = song['ytid'];

    if (ytid == null || ytid.isEmpty) {
      logger.log('makeSongOffline: song["ytid"] is null or empty', null, null);
      return false;
    }

    if (!fromPlaylist && isSongAlreadyOffline(ytid)) {
      return true;
    }

    final audioPath = FilePaths.getAudioPath(ytid);
    final audioFile = File(audioPath);
    final artworkPath = FilePaths.getArtworkPath(ytid);

    await audioFile.parent.create(recursive: true);

    try {
      final audioManifest = await getSongManifest(ytid);
      if (audioManifest == null) {
        logger.log(
          'makeSongOffline: audioManifest is null for $ytid',
          null,
          null,
        );
        return false;
      }

      final stream = _yt.videos.streamsClient.get(audioManifest);
      final fileStream = audioFile.openWrite();
      await stream.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();
    } catch (e, stackTrace) {
      logger.log('Error downloading audio file', e, stackTrace);
      if (await audioFile.exists()) {
        await audioFile.delete();
      }
      return false;
    }

    try {
      if (song['highResImage'] != null &&
          song['highResImage'].toString().isNotEmpty) {
        final _artworkFile = await _downloadAndSaveArtworkFile(
          song['highResImage'],
          artworkPath,
        );

        if (_artworkFile != null && await _artworkFile.exists()) {
          song['artworkPath'] = artworkPath;
          song['highResImage'] = artworkPath;
          song['lowResImage'] = artworkPath;
        } else {
          logger.log(
            'Artwork download failed or file does not exist for $ytid',
            null,
            null,
          );
          // Clear artwork paths if download failed
          song['artworkPath'] = null;
        }
      }
    } catch (e, stackTrace) {
      logger.log('Error downloading artwork', e, stackTrace);
      song['artworkPath'] = null;
    }

    song['audioPath'] = audioFile.path;
    song['isOffline'] = true;
    song['dateAdded'] = DateTime.now().millisecondsSinceEpoch;
    if (!fromPlaylist) {
      userOfflineSongs.add(song);
      await addOrUpdateData('userNoBackup', 'offlineSongs', userOfflineSongs);
      currentOfflineSongsLength.value = userOfflineSongs.length;
    }

    return true;
  } catch (e, stackTrace) {
    logger.log('Error making song offline', e, stackTrace);
    return false;
  }
}

Future<bool> removeSongFromOffline(
  dynamic songId, {
  bool fromPlaylist = false,
}) async {
  try {
    final audioPath = FilePaths.getAudioPath(songId);
    final audioFile = File(audioPath);
    final artworkPath = FilePaths.getArtworkPath(songId);
    final artworkFile = File(artworkPath);

    try {
      if (await audioFile.exists()) await audioFile.delete(recursive: true);
    } catch (e, stackTrace) {
      logger.log('Error deleting audio file', e, stackTrace);
    }

    try {
      if (await artworkFile.exists()) await artworkFile.delete(recursive: true);
    } catch (e, stackTrace) {
      logger.log('Error deleting artwork file', e, stackTrace);
    }

    if (!fromPlaylist) {
      userOfflineSongs.removeWhere((song) => song['ytid'] == songId);
      currentOfflineSongsLength.value = userOfflineSongs.length;
      await addOrUpdateData('userNoBackup', 'offlineSongs', userOfflineSongs);
    }

    return true;
  } catch (e, stackTrace) {
    logger.log('Error removing song from offline storage', e, stackTrace);
    return false;
  }
}

Future<File?> _downloadAndSaveArtworkFile(String url, String filePath) async {
  try {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final file = File(filePath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes);

      // Validate that the file was actually written
      if (await file.exists() && await file.length() > 0) {
        return file;
      } else {
        logger.log(
          'Artwork file was not written properly: $filePath',
          null,
          null,
        );
        return null;
      }
    } else {
      logger.log(
        'Failed to download file. Status code: ${response.statusCode}',
        null,
        null,
      );
    }
  } catch (e, stackTrace) {
    logger.log('Error downloading and saving file', e, stackTrace);
  }

  return null;
}

const recentlyPlayedSongsLimit = 50;

Future<void> updateRecentlyPlayed(dynamic songId) async {
  try {
    if (userRecentlyPlayed.isNotEmpty &&
        userRecentlyPlayed.length == 1 &&
        userRecentlyPlayed[0]['ytid'] == songId) {
      return;
    }

    if (userRecentlyPlayed.length >= recentlyPlayedSongsLimit) {
      userRecentlyPlayed.removeLast();
    }

    final existingIndex = userRecentlyPlayed.indexWhere(
      (song) => song['ytid'] == songId,
    );
    if (existingIndex != -1) {
      final song = userRecentlyPlayed.removeAt(existingIndex);
      userRecentlyPlayed.insert(0, song);
    } else {
      final newSongDetails = await getSongDetails(0, songId);
      userRecentlyPlayed.insert(0, newSongDetails);
    }
    currentRecentlyPlayedLength.value = userRecentlyPlayed.length;
    await addOrUpdateData('user', 'recentlyPlayedSongs', userRecentlyPlayed);
  } catch (e, stackTrace) {
    logger.log('Error updating recently played', e, stackTrace);
  }
}

Future<void> removeFromRecentlyPlayed(dynamic songId) async {
  if (userRecentlyPlayed.any((song) => song['ytid'] == songId)) {
    userRecentlyPlayed.removeWhere((song) => song['ytid'] == songId);
    currentRecentlyPlayedLength.value = userRecentlyPlayed.length;
    await addOrUpdateData('user', 'recentlyPlayedSongs', userRecentlyPlayed);
  }
}

// Helper function to check if a playlist is a custom playlist
bool isCustomPlaylist(Map playlist) {
  return playlist['source'] == 'user-created' &&
      playlist['ytid'] != null &&
      playlist['ytid'].toString().startsWith('customId-');
}

// Helper function to get a unique identifier for playlists (custom or YouTube)
String getPlaylistId(Map playlist) {
  return playlist['ytid'] ?? '';
}

Future<List<dynamic>> getUserPlaylistsNotInFolders() async {
  // Get all playlist IDs that are in folders
  final playlistsInFolders = <String>{};
  for (final folder in userPlaylistFolders.value) {
    final folderPlaylists = folder['playlists'] as List<dynamic>? ?? [];
    for (final playlist in folderPlaylists) {
      if (playlist['ytid'] != null && playlist['source'] == 'user-youtube') {
        playlistsInFolders.add(playlist['ytid']);
      }
    }
  }

  // Get all YouTube playlists and filter out those in folders
  final allUserPlaylists = await getUserPlaylists();
  return allUserPlaylists.where((playlist) {
    return !playlistsInFolders.contains(playlist['ytid']);
  }).toList();
}

// Helper function to check if a playlist exists anywhere (main lists or folders)
bool playlistExistsAnywhere(String playlistId) {
  // Check in main YouTube playlists
  if (userPlaylists.value.contains(playlistId)) {
    return true;
  }

  // Check in custom playlists
  if (userCustomPlaylists.value.any((p) => p['ytid'] == playlistId)) {
    return true;
  }

  // Check in folders
  for (final folder in userPlaylistFolders.value) {
    final folderPlaylists = folder['playlists'] as List<dynamic>? ?? [];
    if (folderPlaylists.any(
      (p) => p['ytid'] != null && p['ytid'] == playlistId,
    )) {
      return true;
    }
  }

  return false;
}
