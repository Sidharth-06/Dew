import 'package:dew/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dew/API/musify.dart';
import 'package:audio_service/audio_service.dart';

class JamSessionManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> startJamSession(
      String friendId, MediaItem currentSong, Duration position) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Create jam session
      final sessionDoc = await _firestore.collection('jam_sessions').add({
        'hostId': currentUser.uid,
        'friendId': friendId,
        'songId': currentSong.id,
        'position': position.inMilliseconds,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending'
      });

      // Send invitation
      await _firestore.collection('jam_invites').add({
        'from_user_id': currentUser.uid,
        'to_user_id': friendId,
        'song_id': currentSong.id,
        'session_id': sessionDoc.id,
        'position': position.inMilliseconds,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending'
      });
    } catch (e) {
      print('Error starting jam session: $e');
    }
  }

  static Future<void> joinJamSession(
      String sessionId, String songId, int position) async {
    try {
      // Get song details
      final songDetails = await getSongDetails(0, songId);

      // Update session status
      await _firestore.collection('jam_sessions').doc(sessionId).update({
        'status': 'active',
        'lastUpdate': FieldValue.serverTimestamp(),
      });

      // Start playing the song
      await audioHandler.playSong(songDetails);

      // Seek to the synchronized position
      await audioHandler.seek(Duration(milliseconds: position));

      jamSessionData.value = {
        'sessionId': sessionId,
        'songId': songId,
        'position': position
      };
    } catch (e) {
      print('Error joining jam session: $e');
    }
  }

  static Future<void> syncPosition(String sessionId, int position) async {
    try {
      await _firestore.collection('jam_sessions').doc(sessionId).update({
        'position': position,
        'lastUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error syncing position: $e');
    }
  }

  static Stream<DocumentSnapshot> getSessionUpdates(String sessionId) {
    return _firestore.collection('jam_sessions').doc(sessionId).snapshots();
  }

  static Future<void> endJamSession(String sessionId) async {
    try {
      await _firestore.collection('jam_sessions').doc(sessionId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });
      jamSessionData.value = null;
    } catch (e) {
      print('Error ending jam session: $e');
    }
  }
}
