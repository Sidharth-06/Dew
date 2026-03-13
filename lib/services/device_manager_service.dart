import 'package:dew/services/logger_service.dart';

class DeviceManagerService {
  static final DeviceManagerService _instance =
      DeviceManagerService._internal();
  factory DeviceManagerService() => _instance;
  DeviceManagerService._internal();

  final Logger _logger = Logger();

  Future<void> registerDevice() async {
    _logger.log(
        'DeviceManagerService: Migration to Appwrite pending.', null, null);
  }

  Future<void> updateLastActive() async {
    // TODO: Implement with Appwrite
  }
}
