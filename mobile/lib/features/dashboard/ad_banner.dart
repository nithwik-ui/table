import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart';
import '../../core/ad_service.dart';

/// Non-blocking Banner Ad widget managed exclusively through [AdService] (InMobi Banner).
///
/// Collapses silently to 0px (`SizedBox.shrink()`) when ads are disabled,
/// unavailable, or fail to load. Never blocks UI or mimics timetable cards.
class AdBanner extends StatefulWidget {
  final String? placementId;
  const AdBanner({super.key, this.placementId});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  InMobiBannerResult? _bannerResult;
  bool _isLoading = false;
  int _retryCount = 0;
  Timer? _retryTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (kIsWeb || !AdService.instance.enabled) return;
    if (_bannerResult == null && !_isLoading) {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    if (_isLoading || !AdService.instance.enabled) return;
    _isLoading = true;

    try {
      final width = MediaQuery.of(context).size.width.truncate().clamp(300, 728);
      final result = await AdService.instance.loadBanner(
        placementId: widget.placementId,
        width: width,
        height: 50,
      );

      if (!mounted) return;

      if (result.loaded) {
        setState(() {
          _bannerResult = result;
          _isLoading = false;
          _retryCount = 0;
        });
      } else {
        setState(() {
          _bannerResult = null;
          _isLoading = false;
        });
        if (_retryCount < 2 &&
            AdService.instance.sdkStatus == AdSdkStatus.ready) {
          _retryCount++;
          _retryTimer?.cancel();
          _retryTimer = Timer(Duration(seconds: 20 * _retryCount), () {
            if (mounted && _bannerResult == null && !_isLoading) {
              _loadAd();
            }
          });
        }
      }
    } catch (e) {
      _isLoading = false;
      debugPrint('[INMOBI] Banner widget load caught (non-fatal): $e');
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    if (_bannerResult != null) {
      AdService.instance.disposeBanner(_bannerResult!.instanceId);
      _bannerResult = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !AdService.instance.enabled) {
      return const SizedBox.shrink();
    }
    if (_bannerResult != null && _bannerResult!.loaded) {
      return Container(
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppConstants.surface,
          border: Border(
            top: BorderSide(color: AppConstants.outline, width: 0.5),
          ),
        ),
        child: SizedBox(
          width: _bannerResult!.width.toDouble(),
          height: _bannerResult!.height.toDouble(),
          child: defaultTargetPlatform == TargetPlatform.android
              ? AndroidView(
                  viewType: 'com.srutimetable.mobile/inmobi_banner_view',
                  creationParams: {
                    'instanceId': _bannerResult!.instanceId,
                    'placementId': _bannerResult!.placementId,
                  },
                  creationParamsCodec: const StandardMessageCodec(),
                )
              : const SizedBox.shrink(),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
