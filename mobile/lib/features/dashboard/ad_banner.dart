import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/ad_service.dart';

class AdBanner extends StatefulWidget {
  final String? adUnitId;
  const AdBanner({super.key, this.adUnitId});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isLoading = false;
  int _retryCount = 0;
  Timer? _retryTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (kIsWeb) return;
    if (_bannerAd == null && !_isLoading && !_isLoaded) {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    if (_isLoading || _bannerAd != null) return;
    _isLoading = true;

    try {
      await AdService.instance.init();
      if (!mounted) return;

      final unitId = widget.adUnitId ?? AdService.instance.bannerAdUnitId;
      if (unitId.isEmpty) {
        _isLoading = false;
        return;
      }

      final AnchoredAdaptiveBannerAdSize? size =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
              MediaQuery.of(context).size.width.truncate());

      if (size == null) {
        _isLoading = false;
        return;
      }

      _bannerAd = BannerAd(
        adUnitId: unitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (Ad ad) {
            if (mounted) {
              setState(() {
                _bannerAd = ad as BannerAd;
                _isLoaded = true;
                _isLoading = false;
                _retryCount = 0;
              });
              debugPrint('[ADMOB] Banner ad loaded successfully');
            }
          },
          onAdFailedToLoad: (Ad ad, LoadAdError error) {
            debugPrint('[ADMOB] Banner ad load failed: code=${error.code}, message=${error.message}');
            ad.dispose();
            _bannerAd = null;
            if (mounted) {
              setState(() {
                _isLoaded = false;
                _isLoading = false;
              });
              if (_retryCount < 3) {
                _retryCount++;
                _retryTimer?.cancel();
                _retryTimer = Timer(Duration(seconds: 15 * _retryCount), () {
                  if (mounted && !_isLoaded && !_isLoading) {
                    _loadAd();
                  }
                });
              }
            }
          },
        ),
      );
      await _bannerAd!.load();
    } catch (e) {
      _isLoading = false;
      debugPrint('[ADMOB] Banner ad load failed (non-fatal): $e');
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    if (_bannerAd != null && _isLoaded) {
      return ClipRect(
        child: Container(
          color: Colors.transparent,
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          alignment: Alignment.center,
          child: AdWidget(ad: _bannerAd!),
        ),
      );
    }
    return const SizedBox.shrink(); // Silent collapse — never blocks or displays empty space
  }
}

