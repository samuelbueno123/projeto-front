import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_front/core/services/realtime_service.dart';

void main() {
  group('RealtimeService and RealtimeEvent', () {
    test('correctly parses RealtimeEvent from JSON', () {
      final json = {
        'type': 'CHAT_MESSAGE',
        'condominiumId': 42,
        'data': {
          'id': 100,
          'message': 'Olá da portaria',
          'senderName': 'Porteiro José',
        },
        'timestamp': '2026-11-02T16:30:00',
      };

      final event = RealtimeEvent.fromJson(json);

      expect(event.type, 'CHAT_MESSAGE');
      expect(event.condominiumId, 42);
      expect(event.data['message'], 'Olá da portaria');
      expect(event.timestamp, isNotNull);
      expect(event.timestamp!.hour, 16);
      expect(event.timestamp!.minute, 30);
    });

    test('parses unknown/null attributes gracefully', () {
      final json = <String, dynamic>{};
      final event = RealtimeEvent.fromJson(json);

      expect(event.type, 'UNKNOWN');
      expect(event.condominiumId, isNull);
      expect(event.data, isNull);
      expect(event.timestamp, isNull);
    });

    test('initial state is disconnected and stream works', () async {
      final service = RealtimeService.instance;
      expect(service.state, RealtimeConnectionState.disconnected);

      // Verify events stream is a broadcast stream
      expect(service.events.isBroadcast, isTrue);
      expect(service.connectionState.isBroadcast, isTrue);
    });

    test('disconnect clears token by default and stays disconnected on connect', () {
      final service = RealtimeService.instance;
      service.setToken('token-user-a');
      expect(service.hasToken, isTrue);

      service.disconnect();
      expect(service.hasToken, isFalse);
      expect(service.state, RealtimeConnectionState.disconnected);

      service.connect();
      expect(service.state, RealtimeConnectionState.disconnected);
    });

    test('disconnect with clearToken false preserves token', () {
      final service = RealtimeService.instance;
      service.setToken('token-user-b');
      expect(service.hasToken, isTrue);

      service.disconnect(clearToken: false);
      expect(service.hasToken, isTrue);
      expect(service.state, RealtimeConnectionState.disconnected);

      service.disconnect();
      expect(service.hasToken, isFalse);
    });
  });
}
