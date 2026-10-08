import 'package:html/parser.dart' as html_parser;
import '../storage.dart';

class SruProfileParser {
  static Map<String, dynamic> parseProfile(String htmlContent, String role) {
    final document = html_parser.parse(htmlContent);
    final Map<String, dynamic> profile = {};

    profile['role'] = role;

    // 1. Look for name (e.g., "Welcome: KURRE NITHWIK REDDY")
    final nameHeaders = document.querySelectorAll('h1, h2, h3, h4, h5, h6, strong, b, .welcome-user');
    for (var el in nameHeaders) {
      final text = el.text.trim();
      if (text.toLowerCase().contains('welcome')) {
        profile['name'] = text.replaceAll(RegExp(r'welcome[\s:]+', caseSensitive: false), '').trim();
        break;
      }
    }

    // 2. Look for batch (e.g., "My Timetable - 24BTCAICYB02" or "Batch Number - 24BTCAICYB02")
    final batchElements = document.querySelectorAll('h1, h2, h3, h4, h5, h6, span, div, td, b');
    for (var el in batchElements) {
      final text = el.text.trim();
      final match = RegExp(r'(?:my timetable\s*-\s*|batch\s*(?:number)?\s*[-:]\s*)([A-Za-z0-9_-]+)', caseSensitive: false).firstMatch(text);
      if (match != null) {
        final batch = match.group(1)!.trim();
        profile['batch'] = batch;
        profile['department'] = batch;
        break;
      }
    }

    // 3. Look for Roll Number / Student ID (e.g. "2403A53050 - KURRE NITHWIK REDDY" or table cells)
    for (var el in batchElements) {
      final text = el.text.trim();
      final rollMatch = RegExp(r'\b(2[0-9][0-9A-Za-z]{2}[A-Za-z0-9]{6})\b').firstMatch(text);
      if (rollMatch != null) {
        profile['id'] = rollMatch.group(1)!.trim();
        profile['roll_number'] = rollMatch.group(1)!.trim();
        break;
      }
    }

    // 4. Attempt to extract other details like ID, Email, Mobile from definition lists or tables
    final labels = document.querySelectorAll('th, td, dt, dd, span, p');
    for (int i = 0; i < labels.length; i++) {
      final text = labels[i].text.toLowerCase().trim();
      
      if (text.contains('roll no') || text.contains('student id') || text.contains('enrollment') || text.contains('ht no')) {
         if (i + 1 < labels.length && !profile.containsKey('id')) {
           final val = labels[i+1].text.trim();
           if (val.isNotEmpty) {
             profile['id'] = val;
             profile['roll_number'] = val;
           }
         }
      } else if (text.contains('faculty id') || text.contains('employee id')) {
         if (i + 1 < labels.length && !profile.containsKey('id')) profile['id'] = labels[i+1].text.trim();
      } else if (text.contains('department') || text.contains('branch')) {
         if (i + 1 < labels.length && !profile.containsKey('department')) profile['department'] = labels[i+1].text.trim();
      } else if (text.contains('email')) {
         if (i + 1 < labels.length && !profile.containsKey('email')) profile['email'] = labels[i+1].text.trim();
      } else if (text.contains('mobile') || text.contains('phone')) {
         if (i + 1 < labels.length && !profile.containsKey('mobile')) profile['mobile'] = labels[i+1].text.trim();
      }
    }

    // 5. Fallback from StorageService if missing
    final storedRoll = StorageService.getStudentRollNumber();
    final storedIdentifier = StorageService.getUserIdentifier();

    if (!profile.containsKey('id') || profile['id'] == 'Unknown') {
      if (storedRoll != null && storedRoll.isNotEmpty) {
        profile['id'] = storedRoll;
        profile['roll_number'] = storedRoll;
      } else if (storedIdentifier != null && storedIdentifier.isNotEmpty) {
        profile['id'] = storedIdentifier;
      }
    }

    if (!profile.containsKey('name')) {
      profile['name'] = StorageService.getUserName() ?? (role == 'faculty' ? 'Faculty' : 'Student');
    }

    if (!profile.containsKey('department')) {
      profile['department'] = role == 'faculty' ? 'Faculty Mode' : 'Student Mode';
    }

    return profile;
  }
}

