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

    // 3. Merge contiguous classes and group simultaneous options
    final List<Map<String, dynamic>> merged = [];
    
    for (final c in uniqueClasses) {
      if (merged.isEmpty) {
        merged.add(_createClassGroup(c));
        continue;
      }

      final prev = merged.last;
      
      // Are they on the same day?
      if (_dayValue(c['day']) != _dayValue(prev['day'])) {
        merged.add(_createClassGroup(c));
        continue;
      }

      // Are they simultaneous options?
      if (c['start_time'] == prev['start_time'] && c['end_time'] == prev['end_time']) {
         if (_isEffectivelySameClass(prev, c)) {
             // Already in there, skip
         } else {
             // Add as an option
             prev['options'] ??= [Map<String, dynamic>.from(prev)..remove('options')];
             
             // Ensure this option isn't already added
             bool optionExists = false;
             for (final opt in prev['options']) {
                if (_isEffectivelySameClass(opt, c)) {
                   optionExists = true;
                   break;
                }
             }
             
             if (!optionExists) {
               final opt = Map<String, dynamic>.from(c);
               opt.remove('options');
               prev['options'].add(opt);
               prev['is_choice'] = true;
               
               // Use a generic placeholder for the main display if there are multiple choices
               prev['subject'] = 'Course Option';
               prev['faculty'] = 'Multiple';
               prev['room'] = 'Multiple';
               prev['ltp'] = '';
             }
         }
         continue;
      }
      
      // Are they contiguous blocks of the SAME class?
      if (c['start_time'] == prev['end_time'] && prev['options'] == null && _isEffectivelySameClass(prev, c, ignoreTime: true)) {
          // Merge them!
          prev['end_time'] = c['end_time'];
          continue;
      }
      
      // Otherwise, just a new class
      merged.add(_createClassGroup(c));
    }
    
    return merged;
  }

  static Map<String, dynamic> _createClassGroup(Map<String, dynamic> c) {
    return Map<String, dynamic>.from(c);
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
