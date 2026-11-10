import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projeto_front/core/http/api_exception.dart';
import 'package:projeto_front/core/http/http_client_wrapper.dart';

void main() {
  test('uses the configured base URL and bearer token', () async {
    http.Request? capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    final api = HttpClientWrapper(
      httpClient: client,
      baseUrl: 'https://api.example.test',
      authToken: 'session-token',
    );

    final response = await api.get<Map<String, dynamic>>(
      '/memberships/my',
      fromJsonT: (json) => json,
    );

    expect(
      capturedRequest?.url,
      Uri.parse('https://api.example.test/memberships/my'),
    );
    expect(capturedRequest?.headers['authorization'], 'Bearer session-token');
    expect(capturedRequest?.headers['x-correlation-id'], isNotNull);
    expect(response.data, {'ok': true});
  });

  test('parses JSON array responses for list endpoints', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode([
          {'id': 1, 'condominiumId': 10, 'authority': 'ROLE_DOORMAN'},
        ]),
        200,
      );
    });
    final api = HttpClientWrapper(
      httpClient: client,
      baseUrl: 'https://api.example.test',
      authToken: 'session-token',
    );

    final response = await api.get<dynamic>(
      '/memberships/my',
      fromJsonT: (json) => json,
    );

    expect(response.data, isA<List<dynamic>>());
    expect((response.data as List).first['authority'], 'ROLE_DOORMAN');
  });

  test('preserves query parameters embedded in endpoint path', () async {
    http.Request? capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(jsonEncode({'content': []}), 200);
    });
    final api = HttpClientWrapper(
      httpClient: client,
      baseUrl: 'https://api.example.test',
      authToken: 'session-token',
    );

    await api.get<dynamic>(
      '/admin/data/users?page=0&size=25&query=maria',
      fromJsonT: (json) => json,
    );

    expect(
      capturedRequest?.url,
      Uri.parse(
        'https://api.example.test/admin/data/users?page=0&size=25&query=maria',
      ),
    );
  });

  test('generates and propagates X-Correlation-ID header on outgoing requests', () async {
    http.Request? capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(jsonEncode({'success': true}), 200);
    });
    final api = HttpClientWrapper(
      httpClient: client,
      baseUrl: 'https://api.example.test',
    );

    await api.get<dynamic>('/health');

    final correlationId = capturedRequest?.headers['x-correlation-id'];
    expect(correlationId, isNotNull);
    expect(correlationId!.startsWith('req-'), isTrue);
  });

  test('preserves explicit X-Correlation-ID when passed in customHeaders', () async {
    http.Request? capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(jsonEncode({'success': true}), 200);
    });
    final api = HttpClientWrapper(
      httpClient: client,
      baseUrl: 'https://api.example.test',
    );

    await api.get<dynamic>(
      '/users/me',
      customHeaders: {'X-Correlation-ID': 'trace-custom-998877'},
    );

    expect(capturedRequest?.headers['x-correlation-id'], 'trace-custom-998877');
  });

  test('associates correlationId with ApiException on server error (500)', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'timestamp': '2026-11-10T12:00:00Z',
          'status': 500,
          'error': 'Internal Server Error',
          'message': 'Erro inesperado no servidor',
          'correlationId': 'err-trace-12345',
        }),
        500,
        headers: {'x-correlation-id': 'err-trace-12345'},
      );
    });
    final api = HttpClientWrapper(
      httpClient: client,
      baseUrl: 'https://api.example.test',
    );

    expect(
      () => api.get<dynamic>('/reports/export'),
      throwsA(
        isA<ServerException>().having(
          (e) => e.correlationId,
          'correlationId',
          'err-trace-12345',
        ).having(
          (e) => e.displayMessage,
          'displayMessage',
          contains('Código de rastreamento: err-trace-12345'),
        ),
      ),
    );
  });

  test('retries transient HTTP 503 error on idempotent GET requests', () async {
    int attempts = 0;
    final client = MockClient((request) async {
      attempts++;
      if (attempts == 1) {
        return http.Response('Service Temporarily Unavailable', 503);
      }
      return http.Response(jsonEncode({'recovered': true}), 200);
    });

    final api = HttpClientWrapper(
      httpClient: client,
      baseUrl: 'https://api.example.test',
    );

    final response = await api.get<Map<String, dynamic>>(
      '/actuator/health',
      fromJsonT: (json) => json,
    );

    expect(attempts, 2);
    expect(response.data, {'recovered': true});
  });

  test('deduplicates simultaneous in-flight GET requests to the same endpoint', () async {
    int networkCalls = 0;
    final client = MockClient((request) async {
      networkCalls++;
      await Future.delayed(const Duration(milliseconds: 50));
      return http.Response(jsonEncode({'data': 'deduplicated'}), 200);
    });

    final api = HttpClientWrapper(
      httpClient: client,
      baseUrl: 'https://api.example.test',
    );

    // Dispara 3 requisições simultâneas em paralelo
    final futures = await Future.wait([
      api.get<Map<String, dynamic>>('/condominiums/1/features'),
      api.get<Map<String, dynamic>>('/condominiums/1/features'),
      api.get<Map<String, dynamic>>('/condominiums/1/features'),
    ]);

    expect(networkCalls, 1);
    expect(futures.length, 3);
    for (final res in futures) {
      expect(res.data, {'data': 'deduplicated'});
    }
  });

  test('caches GET response for specified cacheDuration and serves without hitting network', () async {
    int networkCalls = 0;
    final client = MockClient((request) async {
      networkCalls++;
      return http.Response(jsonEncode({'items': [1, 2, 3]}), 200);
    });

    final api = HttpClientWrapper(
      httpClient: client,
      baseUrl: 'https://api.example.test',
    );

    // Primeira chamada: consulta rede e salva cache
    final res1 = await api.get<Map<String, dynamic>>(
      '/roles',
      cacheDuration: const Duration(seconds: 10),
    );
    expect(networkCalls, 1);
    expect(res1.data, {'items': [1, 2, 3]});

    // Segunda chamada sequencial: deve vir do cache
    final res2 = await api.get<Map<String, dynamic>>(
      '/roles',
      cacheDuration: const Duration(seconds: 10),
    );
    expect(networkCalls, 1); // Sem chamada extra de rede
    expect(res2.data, {'items': [1, 2, 3]});

    // Invalida cache explicitamente
    api.invalidateCache();

    // Terceira chamada: deve bater na rede novamente
    final res3 = await api.get<Map<String, dynamic>>(
      '/roles',
      cacheDuration: const Duration(seconds: 10),
    );
    expect(networkCalls, 2);
    expect(res3.data, {'items': [1, 2, 3]});
  });
}

