import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdBanner extends StatefulWidget {
  final String? adUnitId;
  const AdBanner({super.key, this.adUnitId});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  // Test ID for debug builds, production ID for release builds
  final String _testAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-3940256099942544/2934735716';

  final String _prodAdUnitId = 'ca-app-pub-4600395533739943/8970984870';

  String get _currentAdUnitId => _prodAdUnitId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bannerAd == null) {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    try {
      final AnchoredAdaptiveBannerAdSize? size =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
              MediaQuery.of(context).size.width.truncate());

      if (size == null) return;

      _bannerAd = BannerAd(
        adUnitId: widget.adUnitId ?? _currentAdUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (Ad ad) {
            if (mounted) {
              setState(() {
                _bannerAd = ad as BannerAd;
                _isLoaded = true;
              });
            }
          },
          onAdFailedToLoad: (Ad ad, LoadAdError error) {
            ad.dispose();
            if (mounted) {
              setState(() => _isLoaded = false);
            }
          },
        ),
      );
      _bannerAd!.load();
    } catch (e) {
      debugPrint('Banner ad load failed (non-fatal): $e');
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bannerAd != null && _isLoaded) {
      return Container(
        color: Colors.transparent,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        alignment: Alignment.center,
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return const SizedBox.shrink(); // Silent failure — never blocks the app
  }
}
