import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

enum MicPermission { granted, denied, permanentlyDenied }

/// Microphone permission behind an interface, so tests do not need a phone.
abstract class MicPermissionGateway {
  /// Asks the user (a no-op when already granted).
  Future<MicPermission> request();

  /// Opens the system settings page of this app, for users who chose "Don't ask again".
  Future<bool> openSettings();
}

class SystemMicPermissionGateway implements MicPermissionGateway {
  @override
  Future<MicPermission> request() async {
    final status = await Permission.microphone.request();
    if (status.isGranted || status.isLimited) return MicPermission.granted;
    if (status.isPermanentlyDenied || status.isRestricted) return MicPermission.permanentlyDenied;
    return MicPermission.denied;
  }

  @override
  Future<bool> openSettings() => openAppSettings();
}

final micPermissionProvider = Provider<MicPermissionGateway>((ref) => SystemMicPermissionGateway());
