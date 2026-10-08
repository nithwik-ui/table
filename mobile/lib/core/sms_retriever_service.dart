import 'package:flutter/foundation.dart';
import 'package:pinput/pinput.dart';
import 'package:smart_auth/smart_auth.dart';

class SmartAuthUserConsentRetriever implements SmsRetriever {
  const SmartAuthUserConsentRetriever();

  @override
  Future<void> dispose() async {
    try {
      await SmartAuth.instance.removeUserConsentApiListener();
    } catch (e) {
      debugPrint('Error removing User Consent listener: $e');
    }
  }

  @override
  Future<String?> getSmsCode() async {
    try {
      final res = await SmartAuth.instance.getSmsWithUserConsentApi(
        matcher: r'\b\d{6}\b',
      );
      if (res.hasData && res.data?.code != null) {
        debugPrint('SmartAuth extracted OTP: ${res.data!.code}');
        return res.data!.code;
      }
    } catch (e) {
      debugPrint('Error getting SMS code via SmartAuth: $e');
    }
    return null;
  }

  @override
  bool get listenForMultipleSms => false;
}
