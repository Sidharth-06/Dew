import 'package:dew/services/logger_service.dart';

class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  final Logger _logger = Logger();

  Future<void> initialize() async {
    _logger.log('CloudSyncService: Migration to Appwrite pending.', null, null);
  }

  Future<void> syncSettings() async {
    // TODO: Implement with Appwrite Databases
  }

  Future<void> syncPlaylists() async {
    // TODO: Implement with Appwrite Databases
  }
}
