import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_front/features/community/data/community_api.dart';
import 'package:projeto_front/features/community/presentation/views/doorman_community_views.dart';
import 'package:projeto_front/features/home/data/home_service.dart';

void main() {
  testWidgets('DoormanPlateCheckView renders search field and button', (tester) async {
    final api = HomeService(token: 'mock-token');
    final communityApi = CommunityApi(api: api);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DoormanPlateCheckView(
            api: communityApi,
            condominiumId: 1,
          ),
        ),
      ),
    );

    expect(find.text('Consultar Placa do Veículo'), findsOneWidget);
    expect(find.text('Consultar'), findsOneWidget);
  });
}
