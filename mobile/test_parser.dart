import 'dart:io';
import 'package:html/parser.dart' as html_parser;

void main() {
  final html = File('../sraap_dashboard.html').readAsStringSync();
  final document = html_parser.parse(html);
  
  var table = document.getElementById('attendanceTable');
  if (table == null) {
    final tables = document.querySelectorAll('table');
    for (var t in tables) {
      if (t.text.contains('Course Name') && t.text.contains('LTP Cls')) {
        table = t;
        break;
      }
    }
  }

  if (table != null) {
    print('Found table!');
    final tbody = table.querySelector('tbody');
    if (tbody != null) {
      final rows = tbody.querySelectorAll('tr');
      print('Tbody has ${rows.length} rows');
      for (var row in rows) {
        final cells = row.children.where((e) => e.localName == 'td' || e.localName == 'th').toList();
        if (cells.length >= 5) {
          print('Valid row: ${cells[1].text.trim()}');
        } else {
          print('Invalid row! Cells length: ${cells.length}');
        }
      }
    } else {
      print('Tbody is null');
    }
  }
}
