import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
}
