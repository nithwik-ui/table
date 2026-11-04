import 'dart:js_interop';

@JS('showPwaNotification')
external bool? _jsShowPwaNotification(JSString title, JSString body, JSString tag);

@JS('isPwaNotificationGranted')
external bool? _jsIsPwaNotificationGranted();

@JS('requestPwaNotificationPermission')
external JSPromise<JSString>? _jsRequestPwaNotificationPermission();

class WebNotifications {
  static bool get isSupported => true;

  static bool get isGranted {
    try {
      return _jsIsPwaNotificationGranted() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<String> requestPermission() async {
    try {
      final promise = _jsRequestPwaNotificationPermission();
      if (promise == null) return 'unsupported';
      final res = await promise.toDart;
      return res.toDart;
    } catch (_) {
      return 'denied';
    }
  }

  static bool show({
    required String title,
    required String body,
    String? tag,
  }) {
    try {
      return _jsShowPwaNotification(
        title.toJS,
        body.toJS,
        (tag ?? 'sru_class_reminder').toJS,
      ) ?? false;
    } catch (_) {
      return false;
    }
  }
}

