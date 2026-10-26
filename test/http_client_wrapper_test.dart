import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:projeto_front/core/http/http_client_wrapper.dart';
import 'package:projeto_front/core/http/api_exception.dart';
import 'package:projeto_front/features/home/data/home_service.dart';

void main() {
  group('HttpClientWrapper Tests', () {
    test('builds URL correctly and includes Bearer token', () async {
      late Uri capturedUri;
      late Map<String, String> capturedHeaders;

      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        return http.Response(jsonEncode({'message': 'ok', 'id': 123}), 200);
      });

      final wrapper = HttpClientWrapper(
        httpClient: mockClient,
        baseUrl: 'http://localhost:8080',
        authToken: 'test_jwt_token',
      );

      final response = await wrapper.get<Map<String, dynamic>>(
        '/users/me',
        fromJsonT: (json) => json,
      );

      expect(capturedUri.toString(), 'http://localhost:8080/users/me');
      expect(capturedHeaders['Authorization'], 'Bearer test_jwt_token');
      expect(response.data!['id'], 123);
    });

    test('handles 401 Unauthorized exception correctly', () async {
      bool unauthorizedCalled = false;
      HttpClientWrapper.onUnauthorized = () {
        unauthorizedCalled = true;
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'message': 'Unauthorized'}), 401);
      });

      final wrapper = HttpClientWrapper(
        httpClient: mockClient,
        baseUrl: 'http://localhost:8080',
        authToken: 'expired_token',
      );

      expect(
        () => wrapper.get<dynamic>('/users/me'),
        throwsA(isA<UnauthorizedException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(unauthorizedCalled, isTrue);
    });

    test('handles 404 NotFound exception', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'message': 'Not found'}), 404);
      });

      final wrapper = HttpClientWrapper(
        httpClient: mockClient,
        baseUrl: 'http://localhost:8080',
      );

      expect(
        () => wrapper.get<dynamic>('/condominiums/999'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('HomeService Tests', () {
    test('send calls PATCH method with body correctly', () async {
      late String capturedMethod;
      late Uri capturedUri;
      late String capturedBody;

      final mockClient = MockClient((request) async {
        capturedMethod = request.method;
        capturedUri = request.url;
        capturedBody = request.body;
        return http.Response(jsonEncode({'status': 'RECEIVED'}), 200);
      });

      final service = HomeService(token: 'token123', client: mockClient);

      final result = await service.send('PATCH', '/packages/42/receive');

      expect(capturedMethod, 'PATCH');
      expect(
        capturedUri.toString(),
        'http://localhost:8080/packages/42/receive',
      );
      expect(capturedBody, isEmpty);
      expect(result['status'], 'RECEIVED');
    });

    test('send throws HomeApiException for unsupported HTTP method', () async {
      final mockClient = MockClient((request) async {
        return http.Response('', 200);
      });

      final service = HomeService(token: 'token123', client: mockClient);

      expect(
        () => service.send('TRACE', '/test'),
        throwsA(
          isA<HomeApiException>().having(
            (e) => e.message,
            'message',
            contains('TRACE'),
          ),
        ),
      );
    });
  });
}
