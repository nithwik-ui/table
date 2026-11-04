// Non-web stub for WebNotifications.

class WebNotifications {
  static bool get isSupported => false;
  static bool get isGranted => false;

  static Future<String> requestPermission() async => 'unsupported';

  static bool show({
    required String title,
    required String body,
    String? tag,
  }) => false;
}

