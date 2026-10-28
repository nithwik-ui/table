import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/backend_router.dart';
import 'package:mobile/core/constants.dart';

void main() {
  group('BackendRouter Failure Simulation & Fallback Tests (Section 10 & 30)', () {
    late BackendRouter router;

    setUp(() {
      router = BackendRouter.instance;
    });

    tearDown(() {
      router.testClient = null;
    });

    test('Cloudflare 200 OK: returns Cloudflare response and never calls Render', () async {
      int cloudflareCalls = 0;
      int renderCalls = 0;

      router.testClient = MockClient((request) async {
        if (request.url.toString().startsWith(AppConstants.cloudflarePrimaryUrl)) {
          cloudflareCalls++;
          return http.Response('{"status":"ok_from_cf"}', 200);
        } else if (request.url.toString().startsWith(AppConstants.renderFallbackUrl)) {
          renderCalls++;
          return http.Response('{"status":"ok_from_render"}', 200);
        }
        return http.Response('Not Found', 404);
      });

      final response = await router.get('/health');
      expect(response.statusCode, equals(200));
      expect(response.body, contains('ok_from_cf'));
      expect(cloudflareCalls, equals(1));
      expect(renderCalls, equals(0), reason: 'Render fallback must not be called when Cloudflare returns 2xx');
    });

    test('Cloudflare 400 Bad Request: returns 400 directly and does not fallback', () async {
      int renderCalls = 0;

      router.testClient = MockClient((request) async {
        if (request.url.toString().startsWith(AppConstants.cloudflarePrimaryUrl)) {
          return http.Response('{"error":"Invalid query"}', 400);
        } else {
          renderCalls++;
          return http.Response('{"status":"render"}', 200);
        }
      });

      final response = await router.get('/api/rooms/free');
      expect(response.statusCode, equals(400));
      expect(response.body, contains('Invalid query'));
      expect(renderCalls, equals(0), reason: 'Client errors (4xx) must not trigger fallback');
    });

    test('Cloudflare 401 Unauthorized: returns 401 directly and does not fallback', () async {
      int renderCalls = 0;

      router.testClient = MockClient((request) async {
        if (request.url.toString().startsWith(AppConstants.cloudflarePrimaryUrl)) {
          return http.Response('{"error":"Unauthorized"}', 401);
        } else {
          renderCalls++;
          return http.Response('{"status":"render"}', 200);
        }
      });

      final response = await router.get('/api/admin/faculty');
      expect(response.statusCode, equals(401));
      expect(renderCalls, equals(0));
    });

    test('Cloudflare 404 Not Found: returns 404 directly and does not fallback', () async {
      int renderCalls = 0;

      router.testClient = MockClient((request) async {
        if (request.url.toString().startsWith(AppConstants.cloudflarePrimaryUrl)) {
          return http.Response('{"error":"Batch not found"}', 404);
        } else {
          renderCalls++;
          return http.Response('{"status":"render"}', 200);
        }
      });

      final response = await router.get('/api/degrees/BTECH/years/99/batches');
      expect(response.statusCode, equals(404));
      expect(renderCalls, equals(0));
    });

    test('Cloudflare 429 Rate Limited: returns 429 directly and does not fallback', () async {
      int renderCalls = 0;

      router.testClient = MockClient((request) async {
        if (request.url.toString().startsWith(AppConstants.cloudflarePrimaryUrl)) {
          return http.Response('{"error":"Too Many Requests"}', 429);
        } else {
          renderCalls++;
          return http.Response('{"status":"render"}', 200);
        }
      });

      final response = await router.get('/api/degrees');
      expect(response.statusCode, equals(429));
      expect(renderCalls, equals(0));
    });

    test('Cloudflare 500 Internal Error: falls back to Render automatically', () async {
      int cloudflareCalls = 0;
      int renderCalls = 0;

      router.testClient = MockClient((request) async {
        if (request.url.toString().startsWith(AppConstants.cloudflarePrimaryUrl)) {
          cloudflareCalls++;
          return http.Response('{"error":"Worker crash"}', 500);
        } else if (request.url.toString().startsWith(AppConstants.renderFallbackUrl)) {
          renderCalls++;
          return http.Response('{"status":"ok_from_render"}', 200);
        }
        return http.Response('Not Found', 404);
      });

      final response = await router.get('/api/degrees');
      expect(response.statusCode, equals(200));
      expect(response.body, contains('ok_from_render'));
      expect(cloudflareCalls, equals(1));
      expect(renderCalls, equals(1));
    });

    test('Cloudflare 503 Service Unavailable: falls back to Render automatically', () async {
      int renderCalls = 0;

      router.testClient = MockClient((request) async {
        if (request.url.toString().startsWith(AppConstants.cloudflarePrimaryUrl)) {
          return http.Response('{"error":"Cloudflare Isolate Overloaded"}', 503);
        } else if (request.url.toString().startsWith(AppConstants.renderFallbackUrl)) {
          renderCalls++;
          return http.Response('{"status":"ok_from_render"}', 200);
        }
        return http.Response('Not Found', 404);
      });

      final response = await router.get('/api/degrees');
      expect(response.statusCode, equals(200));
      expect(renderCalls, equals(1));
    });

    test('Cloudflare Network/Socket Exception: falls back to Render automatically', () async {
      int renderCalls = 0;

      router.testClient = MockClient((request) async {
        if (request.url.toString().startsWith(AppConstants.cloudflarePrimaryUrl)) {
          throw const SocketException('Connection refused');
        } else if (request.url.toString().startsWith(AppConstants.renderFallbackUrl)) {
          renderCalls++;
          return http.Response('{"status":"recovered_by_render"}', 200);
        }
        return http.Response('Not Found', 404);
      });

      final response = await router.get('/api/degrees');
      expect(response.statusCode, equals(200));
      expect(response.body, contains('recovered_by_render'));
      expect(renderCalls, equals(1));
    });

    test('Cloudflare Timeout: falls back to Render automatically', () async {
      int renderCalls = 0;

      router.testClient = MockClient((request) async {
        if (request.url.toString().startsWith(AppConstants.cloudflarePrimaryUrl)) {
          throw TimeoutException('Cloudflare request timed out');
        } else if (request.url.toString().startsWith(AppConstants.renderFallbackUrl)) {
          renderCalls++;
          return http.Response('{"status":"recovered_from_timeout"}', 200);
        }
        return http.Response('Not Found', 404);
      });

      final response = await router.get('/api/degrees');
      expect(response.statusCode, equals(200));
      expect(response.body, contains('recovered_from_timeout'));
      expect(renderCalls, equals(1));
    });

    test('Both Cloudflare and Render fail: throws error so caller retains Hive cache', () async {
      router.testClient = MockClient((request) async {
        if (request.url.toString().startsWith(AppConstants.cloudflarePrimaryUrl)) {
          return http.Response('{"error":"CF 500"}', 500);
        } else {
          return http.Response('{"error":"Render 503"}', 503);
        }
      });

      final response = await router.get('/api/degrees');
      expect(response.statusCode, equals(503));
    });

    test('POST request: Cloudflare 200 returns immediately without Render', () async {
      int renderCalls = 0;

      router.testClient = MockClient((request) async {
        if (request.url.toString().startsWith(AppConstants.cloudflarePrimaryUrl)) {
          return http.Response('{"registered":true}', 200);
        } else {
          renderCalls++;
          return http.Response('{"registered":true}', 200);
        }
      });

      final response = await router.post('/api/devices/register', body: '{"token":"xyz"}');
      expect(response.statusCode, equals(200));
      expect(renderCalls, equals(0));
    });

    test('POST request: Cloudflare 500 falls over to Render fallback', () async {
      int renderCalls = 0;

      router.testClient = MockClient((request) async {
        if (request.url.toString().startsWith(AppConstants.cloudflarePrimaryUrl)) {
          return http.Response('{"error":"CF 500"}', 500);
        } else {
          renderCalls++;
          return http.Response('{"registered_on_render":true}', 200);
        }
      });

      final response = await router.post('/api/devices/register', body: '{"token":"xyz"}');
      expect(response.statusCode, equals(200));
      expect(response.body, contains('registered_on_render'));
      expect(renderCalls, equals(1));
    });
  });
}
