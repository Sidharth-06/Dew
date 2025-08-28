import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en')
  ];

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @accentChangeMsg.
  ///
  /// In en, this message translates to:
  /// **'Accent color changed successfully'**
  String get accentChangeMsg;

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get accentColor;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get addToPlaylist;

  /// No description provided for @addedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Added successfully'**
  String get addedSuccess;

  /// No description provided for @album.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get album;

  /// No description provided for @appUpdateIsAvailable.
  ///
  /// In en, this message translates to:
  /// **'App update is available'**
  String get appUpdateIsAvailable;

  /// No description provided for @artist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get artist;

  /// No description provided for @audioQuality.
  ///
  /// In en, this message translates to:
  /// **'Audio quality'**
  String get audioQuality;

  /// No description provided for @audioQualityMsg.
  ///
  /// In en, this message translates to:
  /// **'Audio quality changed successfully'**
  String get audioQualityMsg;

  /// No description provided for @automaticSongPicker.
  ///
  /// In en, this message translates to:
  /// **'Automatic song picker'**
  String get automaticSongPicker;

  /// No description provided for @backedupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data backed up successfully'**
  String get backedupSuccess;

  /// No description provided for @backupError.
  ///
  /// In en, this message translates to:
  /// **'Error occurred while backing up data'**
  String get backupError;

  /// No description provided for @backupUserData.
  ///
  /// In en, this message translates to:
  /// **'Backup user data'**
  String get backupUserData;

  /// No description provided for @becomeSponsor.
  ///
  /// In en, this message translates to:
  /// **'Become a sponsor'**
  String get becomeSponsor;

  /// No description provided for @cacheMsg.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared successfully'**
  String get cacheMsg;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @chooseBackupDir.
  ///
  /// In en, this message translates to:
  /// **'Choose backup directory'**
  String get chooseBackupDir;

  /// No description provided for @chooseRestoreDir.
  ///
  /// In en, this message translates to:
  /// **'Choose restore directory'**
  String get chooseRestoreDir;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get clearCache;

  /// No description provided for @clearRecentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Clear recently played history'**
  String get clearRecentlyPlayed;

  /// No description provided for @clearRecentlyPlayedQuestion.
  ///
  /// In en, this message translates to:
  /// **'Clear recently played history?'**
  String get clearRecentlyPlayedQuestion;

  /// No description provided for @clearSearchHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear search history'**
  String get clearSearchHistory;

  /// No description provided for @clearSearchHistoryQuestion.
  ///
  /// In en, this message translates to:
  /// **'Clear search history?'**
  String get clearSearchHistoryQuestion;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @confirmation.
  ///
  /// In en, this message translates to:
  /// **'Confirmation'**
  String get confirmation;

  /// No description provided for @copyLogs.
  ///
  /// In en, this message translates to:
  /// **'Copy logs'**
  String get copyLogs;

  /// No description provided for @copyLogsNoLogs.
  ///
  /// In en, this message translates to:
  /// **'No logs found to copy'**
  String get copyLogsNoLogs;

  /// No description provided for @copyLogsSuccess.
  ///
  /// In en, this message translates to:
  /// **'Logs copied successfully'**
  String get copyLogsSuccess;

  /// No description provided for @customPlaylistImgUrl.
  ///
  /// In en, this message translates to:
  /// **'Custom playlist image link'**
  String get customPlaylistImgUrl;

  /// No description provided for @customPlaylistName.
  ///
  /// In en, this message translates to:
  /// **'Custom playlist name'**
  String get customPlaylistName;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloadAppUpdate.
  ///
  /// In en, this message translates to:
  /// **'Download app update'**
  String get downloadAppUpdate;

  /// No description provided for @dynamicColor.
  ///
  /// In en, this message translates to:
  /// **'Dynamic accent color (Android 12+)'**
  String get dynamicColor;

  /// No description provided for @enablePredictiveBack.
  ///
  /// In en, this message translates to:
  /// **'Enable predictive back animations (Android 14+)'**
  String get enablePredictiveBack;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get error;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'EXIT'**
  String get exit;

  /// No description provided for @enterTheaterMode.
  ///
  /// In en, this message translates to:
  /// **'Enter Theater Mode'**
  String get enterTheaterMode;

  /// No description provided for @exitTheaterMode.
  ///
  /// In en, this message translates to:
  /// **'Exit Theater Mode'**
  String get exitTheaterMode;

  /// No description provided for @exitSingAlong.
  ///
  /// In en, this message translates to:
  /// **'Exit Sing Along'**
  String get exitSingAlong;

  /// No description provided for @failedToLoadVideo.
  ///
  /// In en, this message translates to:
  /// **'Failed to load video'**
  String get failedToLoadVideo;

  /// No description provided for @featuredPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Featured Playlists'**
  String get featuredPlaylists;

  /// No description provided for @folderRestrictions.
  ///
  /// In en, this message translates to:
  /// **'Due to new restrictions on Android, it is essential to select specific and appropriate folders for different file types. Please ensure that you choose either the \'Documents\' or \'Downloads\' folder for the app backup.'**
  String get folderRestrictions;

  /// No description provided for @hideTheaterElements.
  ///
  /// In en, this message translates to:
  /// **'Hide Theater Elements'**
  String get hideTheaterElements;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @install.
  ///
  /// In en, this message translates to:
  /// **'install now'**
  String get install;

  /// No description provided for @karaokeVersionReady.
  ///
  /// In en, this message translates to:
  /// **'Karaoke version is ready to play'**
  String get karaokeVersionReady;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageMsg.
  ///
  /// In en, this message translates to:
  /// **'Language changed successfully'**
  String get languageMsg;

  /// No description provided for @letsSing.
  ///
  /// In en, this message translates to:
  /// **'Let\'s Sing!'**
  String get letsSing;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get licenses;

  /// No description provided for @likedPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Liked playlists'**
  String get likedPlaylists;

  /// No description provided for @likedSongs.
  ///
  /// In en, this message translates to:
  /// **'Liked songs'**
  String get likedSongs;

  /// No description provided for @likeSong.
  ///
  /// In en, this message translates to:
  /// **'Like song'**
  String get likeSong;

  /// No description provided for @loadingVideo.
  ///
  /// In en, this message translates to:
  /// **'Loading video...'**
  String get loadingVideo;

  /// No description provided for @lyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyrics;

  /// No description provided for @lyricsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Lyrics not available'**
  String get lyricsNotAvailable;

  /// No description provided for @makeOffline.
  ///
  /// In en, this message translates to:
  /// **'Make offline'**
  String get makeOffline;

  /// No description provided for @minimizePlayer.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimizePlayer;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @noCustomPlaylists.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t created any custom playlists yet'**
  String get noCustomPlaylists;

  /// No description provided for @noLikedPlaylists.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t liked any playlists yet'**
  String get noLikedPlaylists;

  /// No description provided for @noLyricsFound.
  ///
  /// In en, this message translates to:
  /// **'No lyrics found'**
  String get noLyricsFound;

  /// No description provided for @notYTlist.
  ///
  /// In en, this message translates to:
  /// **'This is not a valid YouTube playlist ID'**
  String get notYTlist;

  /// No description provided for @noupdate.
  ///
  /// In en, this message translates to:
  /// **'no update available'**
  String get noupdate;

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline mode'**
  String get offlineMode;

  /// No description provided for @offlineSongs.
  ///
  /// In en, this message translates to:
  /// **'Offline songs'**
  String get offlineSongs;

  /// No description provided for @originalRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Original algorithm for recommendations'**
  String get originalRecommendations;

  /// No description provided for @others.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get others;

  /// No description provided for @playlist.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get playlist;

  /// No description provided for @playlistUpdated.
  ///
  /// In en, this message translates to:
  /// **'Playlist updated successfully'**
  String get playlistUpdated;

  /// No description provided for @playlists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// No description provided for @popularArtists.
  ///
  /// In en, this message translates to:
  /// **'Popular Artists'**
  String get popularArtists;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @provideIdOrNameError.
  ///
  /// In en, this message translates to:
  /// **'Please provide a YouTube ID or custom playlist name'**
  String get provideIdOrNameError;

  /// No description provided for @readyToSing.
  ///
  /// In en, this message translates to:
  /// **'Ready to Sing Along!'**
  String get readyToSing;

  /// No description provided for @recentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently Played'**
  String get recentlyPlayed;

  /// No description provided for @recentlyPlayedMsg.
  ///
  /// In en, this message translates to:
  /// **'Recently played history cleared'**
  String get recentlyPlayedMsg;

  /// No description provided for @recommendedForYou.
  ///
  /// In en, this message translates to:
  /// **'Recommended for you'**
  String get recommendedForYou;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removeFromOffline.
  ///
  /// In en, this message translates to:
  /// **'Remove from offline'**
  String get removeFromOffline;

  /// No description provided for @removePlaylistQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove this playlist?'**
  String get removePlaylistQuestion;

  /// No description provided for @removeSearchQueryQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove this search query?'**
  String get removeSearchQueryQuestion;

  /// No description provided for @replay10.
  ///
  /// In en, this message translates to:
  /// **'Replay 10 seconds'**
  String get replay10;

  /// No description provided for @repeatAll.
  ///
  /// In en, this message translates to:
  /// **'Repeat All'**
  String get repeatAll;

  /// No description provided for @repeatOff.
  ///
  /// In en, this message translates to:
  /// **'Repeat Off'**
  String get repeatOff;

  /// No description provided for @repeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat One'**
  String get repeatOne;

  /// No description provided for @restartAppMsg.
  ///
  /// In en, this message translates to:
  /// **'Restart the app to apply the changes'**
  String get restartAppMsg;

  /// No description provided for @restoreError.
  ///
  /// In en, this message translates to:
  /// **'Error occurred while restoring data'**
  String get restoreError;

  /// No description provided for @restoreUserData.
  ///
  /// In en, this message translates to:
  /// **'Restore user data'**
  String get restoreUserData;

  /// No description provided for @restoredSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data restored successfully'**
  String get restoredSuccess;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchHistoryMsg.
  ///
  /// In en, this message translates to:
  /// **'Search history cleared'**
  String get searchHistoryMsg;

  /// No description provided for @settingChangedMsg.
  ///
  /// In en, this message translates to:
  /// **'Settings changed'**
  String get settingChangedMsg;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// No description provided for @showLyrics.
  ///
  /// In en, this message translates to:
  /// **'Show Lyrics'**
  String get showLyrics;

  /// No description provided for @showQueue.
  ///
  /// In en, this message translates to:
  /// **'Show queue'**
  String get showQueue;

  /// No description provided for @showTheaterElements.
  ///
  /// In en, this message translates to:
  /// **'Show Theater Elements'**
  String get showTheaterElements;

  /// No description provided for @singAlongMode.
  ///
  /// In en, this message translates to:
  /// **'Sing Along Mode'**
  String get singAlongMode;

  /// No description provided for @songAdded.
  ///
  /// In en, this message translates to:
  /// **'Song added successfully'**
  String get songAdded;

  /// No description provided for @songRemoved.
  ///
  /// In en, this message translates to:
  /// **'Song removed successfully'**
  String get songRemoved;

  /// No description provided for @songs.
  ///
  /// In en, this message translates to:
  /// **'songs'**
  String get songs;

  /// No description provided for @sponsorProject.
  ///
  /// In en, this message translates to:
  /// **'Sponsor the project'**
  String get sponsorProject;

  /// No description provided for @suggestedArtists.
  ///
  /// In en, this message translates to:
  /// **'Suggested artists'**
  String get suggestedArtists;

  /// No description provided for @suggestedPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Suggested playlists'**
  String get suggestedPlaylists;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get themeMode;

  /// No description provided for @tools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// No description provided for @understand.
  ///
  /// In en, this message translates to:
  /// **'I understand'**
  String get understand;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @unlikeSong.
  ///
  /// In en, this message translates to:
  /// **'Unlike song'**
  String get unlikeSong;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'app update available'**
  String get updateAvailable;

  /// No description provided for @updateDescription.
  ///
  /// In en, this message translates to:
  /// **'Description For each Update'**
  String get updateDescription;

  /// No description provided for @usePureBlack.
  ///
  /// In en, this message translates to:
  /// **'Use pure black'**
  String get usePureBlack;

  /// No description provided for @useSquigglySlider.
  ///
  /// In en, this message translates to:
  /// **'Use squiggly slider'**
  String get useSquigglySlider;

  /// No description provided for @userPlaylists.
  ///
  /// In en, this message translates to:
  /// **'User playlists'**
  String get userPlaylists;

  /// No description provided for @videoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Video unavailable'**
  String get videoUnavailable;

  /// No description provided for @youtubePlaylistID.
  ///
  /// In en, this message translates to:
  /// **'YouTube playlist ID'**
  String get youtubePlaylistID;

  /// No description provided for @checkupdate.
  ///
  /// In en, this message translates to:
  /// **'Check Update'**
  String get checkupdate;

  /// No description provided for @emptyQueue.
  ///
  /// In en, this message translates to:
  /// **'No songs in queue'**
  String get emptyQueue;

  /// No description provided for @videoNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Video not available for this song.'**
  String get videoNotAvailable;

  /// No description provided for @switchToAudio.
  ///
  /// In en, this message translates to:
  /// **'Switch to Audio'**
  String get switchToAudio;

  /// No description provided for @switchToVideo.
  ///
  /// In en, this message translates to:
  /// **'Switch to Video'**
  String get switchToVideo;

  /// No description provided for @theatreMode.
  ///
  /// In en, this message translates to:
  /// **'Theatre Mode'**
  String get theatreMode;

  /// No description provided for @theatreModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Enjoy an immersive viewing experience'**
  String get theatreModeDescription;

  /// No description provided for @enter.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get enter;

  /// No description provided for @exitTheatreMode.
  ///
  /// In en, this message translates to:
  /// **'Exit Theatre Mode'**
  String get exitTheatreMode;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
