class TimetableNormalizer {
  static List<dynamic> normalize(List<dynamic> raw) {
    if (raw.isEmpty) return [];

    List<Map<String, dynamic>> classes = raw.map((e) => Map<String, dynamic>.from(e)).toList();

    // 1. Remove exact duplicates
    final List<Map<String, dynamic>> uniqueClasses = [];
    final seenIds = <String>{};
    for (final c in classes) {
      final key = _generateUniqueKey(c);
      if (!seenIds.contains(key)) {
        seenIds.add(key);
        uniqueClasses.add(c);
      }
    }

    // 2. Sort by Day and Start Time
    uniqueClasses.sort((a, b) {
      final dayDiff = _dayValue(a['day']).compareTo(_dayValue(b['day']));
      if (dayDiff != 0) return dayDiff;
      final startA = _timeValue(a['start_time']);
      final startB = _timeValue(b['start_time']);
      return startA.compareTo(startB);
    });

    // 3. Group simultaneous options
    final List<Map<String, dynamic>> groupedClasses = [];
    for (final c in uniqueClasses) {
      if (groupedClasses.isEmpty) {
        groupedClasses.add(_createClassGroup(c));
      } else {
        final last = groupedClasses.last;
        if (last['day'] == c['day'] && last['start_time'] == c['start_time'] && last['end_time'] == c['end_time']) {
          if (!_isEffectivelySameClass(last, c, ignoreTime: true)) {
            last['is_choice'] = true;
            if (last['options'] == null) {
              last['options'] = [_createClassGroup(last)];
            }
            last['options'].add(_createClassGroup(c));
          }
        } else {
          groupedClasses.add(_createClassGroup(c));
        }
      }
    }

    // 4. Merge contiguous blocks
    final List<Map<String, dynamic>> mergedClasses = [];
    for (final c in groupedClasses) {
      if (mergedClasses.isEmpty) {
        mergedClasses.add(c);
      } else {
        final last = mergedClasses.last;
        if (last['day'] == c['day'] && last['end_time'] == c['start_time'] && _isEffectivelySameGroup(last, c)) {
          last['end_time'] = c['end_time'];
        } else {
          mergedClasses.add(c);
        }
      }
    }

    for (final c in mergedClasses) {
      final day = (c['day']?.toString() ?? '').toLowerCase();
      final start = c['start_time']?.toString() ?? '';
      final end = c['end_time']?.toString() ?? '';
      final sub = _normalizeString(c['subject']?.toString() ?? '');
      final room = _normalizeString(c['room']?.toString() ?? '');
      c['id'] = '${day}_${start}_${end}_${sub}_$room';
    }

    return mergedClasses;
  }

  static Map<String, dynamic> _createClassGroup(Map<String, dynamic> c) {
    final copy = Map<String, dynamic>.from(c);
    copy.remove('is_choice');
    copy.remove('options');
    return copy;
  }

  static bool _isEffectivelySameGroup(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a['is_choice'] != b['is_choice']) return false;
    if (a['is_choice'] == true) {
      final optsA = a['options'] as List;
      final optsB = b['options'] as List;
      if (optsA.length != optsB.length) return false;
      for (int i = 0; i < optsA.length; i++) {
        if (!_isEffectivelySameClass(optsA[i], optsB[i], ignoreTime: true)) return false;
      }
      return true;
    }
    return _isEffectivelySameClass(a, b, ignoreTime: true);
  }

  static String _generateUniqueKey(Map<String, dynamic> c) {
     final day = (c['day']?.toString() ?? '').toLowerCase().trim();
     final start = (c['start_time']?.toString() ?? '').trim();
     final end = (c['end_time']?.toString() ?? '').trim();
     final sub = (c['subject']?.toString() ?? '').toLowerCase().trim();
     final fac = _normalizeString((c['faculty']?.toString() ?? ''));
     final room = _normalizeString((c['room']?.toString() ?? ''));
     final ltp = (c['ltp']?.toString() ?? '').toLowerCase().trim();
     return '$day|$start|$end|$sub|$fac|$room|$ltp';
  }

  static bool _isEffectivelySameClass(Map<String, dynamic> a, Map<String, dynamic> b, {bool ignoreTime = false}) {
     if (!ignoreTime) {
        if (a['start_time'] != b['start_time'] || a['end_time'] != b['end_time']) return false;
     }
     
     final subA = (a['subject']?.toString() ?? '').toLowerCase().trim();
     final subB = (b['subject']?.toString() ?? '').toLowerCase().trim();
     if (subA != subB) return false;
     
     final facA = _normalizeString(a['faculty']?.toString() ?? '');
     final facB = _normalizeString(b['faculty']?.toString() ?? '');
     if (facA != facB) return false;
     
     final roomA = _normalizeString(a['room']?.toString() ?? '');
     final roomB = _normalizeString(b['room']?.toString() ?? '');
     if (roomA != roomB) return false;
     
     final ltpA = (a['ltp']?.toString() ?? '').toLowerCase().trim();
     final ltpB = (b['ltp']?.toString() ?? '').toLowerCase().trim();
     if (ltpA != ltpB) return false;
     
     return true;
  }
  
  static String _normalizeString(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static int _dayValue(dynamic dayStr) {
     final d = (dayStr?.toString() ?? '').toLowerCase();
     switch (d) {
       case 'monday': return 1;
       case 'tuesday': return 2;
       case 'wednesday': return 3;
       case 'thursday': return 4;
       case 'friday': return 5;
       case 'saturday': return 6;
       case 'sunday': return 7;
       default: return 8;
     }
  }

  static int _timeValue(dynamic timeStr) {
     final t = (timeStr?.toString() ?? '');
     if (t.isEmpty) return 0;
     final parts = t.split(':');
     if (parts.length < 2) return 0;
     final h = int.tryParse(parts[0]) ?? 0;
     final m = int.tryParse(parts[1]) ?? 0;
     return h * 60 + m;
  }
}
