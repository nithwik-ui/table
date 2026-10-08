import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

void main() async {
  final baseUrl = 'https://timetable.sruniv.com';
  final client = http.Client();
  Map<String, String> cookies = {};

  // 1. GET request
  final getRes = await client.get(Uri.parse(baseUrl));
  print('GET status: ${getRes.statusCode}');
  
  // Extract token
  final document = html_parser.parse(getRes.body);
  final tokenInput = document.querySelector('input[name="_token"]');
  final token = tokenInput?.attributes['value'];
  print('Token: $token');
  
  // Extract cookies
  final setCookie = getRes.headers['set-cookie'];
  print('GET Set-Cookie: $setCookie');
  
  if (setCookie != null) {
    final parts = setCookie.split(RegExp(r',(?=[a-zA-Z0-9_\-]+=|$)'));
    for (var part in parts) {
      final cookieString = part.split(';').first.trim();
      final equalIndex = cookieString.indexOf('=');
      if (equalIndex != -1) {
        cookies[cookieString.substring(0, equalIndex)] = cookieString.substring(equalIndex + 1);
      }
    }
  }
  
  final cookieHeader = cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  print('Using Cookie: $cookieHeader');
  
  // 2. POST request
  final req = http.Request('POST', Uri.parse(baseUrl));
  req.headers['Content-Type'] = 'application/x-www-form-urlencoded';
  req.headers['Cookie'] = cookieHeader;
  req.headers['User-Agent'] = 'Mozilla/5.0'; // Sometimes required
  
  req.followRedirects = false;
  req.bodyFields = {
    '_token': token ?? '',
    'login_identifier': 'testuser@sruniv.com',
    'password': 'password123',
  };
  
  final streamedRes = await client.send(req);
  final postRes = await http.Response.fromStream(streamedRes);
  
  print('POST status: ${postRes.statusCode}');
  print('POST current URL: ${postRes.request?.url}');
  print('POST Location Header: ${postRes.headers['location']}');
  print('POST body length: ${postRes.body.length}');
  
  if (postRes.body.toLowerCase().contains('invalid')) {
    print('Result: Invalid credentials detected successfully!');
  } else {
    print('Result: Login rejected by SRU (did not reach auth failure block).');
  }
}
