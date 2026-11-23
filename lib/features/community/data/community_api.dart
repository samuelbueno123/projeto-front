import 'dart:typed_data';

import '../../home/data/home_service.dart';

part 'community_api_community_part.dart';
part 'community_api_finance_part.dart';
part 'community_api_governance_part.dart';

class CommunityApi {
  CommunityApi({required this.api});

  final HomeService api;

  // 0. AVALIAÇÃO DE DISPONIBILIDADE E RESERVAS
  Future<Map<String, dynamic>> checkAreaAvailability({
    required num areaId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final startStr = Uri.encodeComponent(startAt.toIso8601String());
    final endStr = Uri.encodeComponent(endAt.toIso8601String());
    final res = await api.get(
      '/common-areas/$areaId/check-availability?startAt=$startStr&endAt=$endStr',
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getAreaAvailability({
    required num areaId,
    required DateTime date,
  }) async {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final res = await api.get(
      '/common-areas/$areaId/availability?date=$dateStr',
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> requestReservation({
    required num areaId,
    required DateTime startAt,
    required DateTime endAt,
    required String contactPhone,
    String? notes,
  }) async {
    final res = await api.send(
      'POST',
      '/common-areas/$areaId/reservations',
      body: {
        'startAt': startAt.toIso8601String(),
        'endAt': endAt.toIso8601String(),
        'contactPhone': contactPhone,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> approveReservation(num reservationId) async {
    await api.send('PATCH', '/reservations/$reservationId/approve');
  }

  Future<void> rejectReservation(num reservationId, [String? reason]) async {
    await api.send(
      'PATCH',
      '/reservations/$reservationId/reject',
      body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  Future<void> cancelReservation(num reservationId) async {
    await api.send('PATCH', '/reservations/$reservationId/cancel');
  }

  Future<Map<String, dynamic>> joinWaitlist({
    required num areaId,
    required DateTime startAt,
    required DateTime endAt,
    required String contactPhone,
    String? notes,
  }) async {
    final res = await api.send(
      'POST',
      '/common-areas/$areaId/waitlist',
      body: {
        'startAt': startAt.toIso8601String(),
        'endAt': endAt.toIso8601String(),
        'contactPhone': contactPhone,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getAreaWaitlist(num areaId) async {
    final res = await api.get('/common-areas/$areaId/waitlist');
    return _asList(res);
  }

  // 0.05 CONFIRMAÇÃO DE LEITURA DE COMUNICADOS
  Future<Map<String, dynamic>> markAnnouncementAsRead(
    num announcementId,
  ) async {
    final res = await api.send('POST', '/announcements/$announcementId/read');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getAnnouncementReaders(
    num announcementId,
  ) async {
    final res = await api.get('/announcements/$announcementId/reads');
    return _asList(res);
  }

  // 0.1 SOLICITAÇÕES DE ENTRADA / VÍNCULO DE MORADOR
  Future<List<Map<String, dynamic>>> getAvailableCondominiums() async {
    final res = await api.get('/condominiums/available');
    return _asList(res);
  }

  Future<List<Map<String, dynamic>>> getAvailableUnits(num condoId) async {
    final res = await api.get('/condominiums/$condoId/available-units');
    return _asList(res);
  }

  Future<List<Map<String, dynamic>>> getCondominiumUnits(num condoId) async {
    final res = await api.get('/units?condominiumId=$condoId');
    return _asList(res);
  }

  Future<List<Map<String, dynamic>>> getMyMembershipRequests() async {
    final res = await api.get('/membership-requests/my');
    return _asList(res);
  }

  Future<Map<String, dynamic>> createMembershipRequest({
    required num condoId,
    required String authority,
    num? unitId,
    String? residentType,
    String? message,
  }) async {
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/membership-requests',
      body: {
        'authority': authority,
        if (unitId != null) 'unitId': unitId,
        if (residentType != null) 'residentType': residentType,
        if (message != null && message.isNotEmpty) 'message': message,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> approveMembershipRequest({
    required num condoId,
    required num membershipId,
    num? unitId,
    String? residentType,
  }) async {
    await api.send(
      'POST',
      '/manager/condominiums/$condoId/membership-requests/$membershipId/approve',
      body: {
        if (unitId != null) 'unitId': unitId,
        if (residentType != null) 'residentType': residentType,
      },
    );
  }

  Future<void> rejectMembershipRequest({
    required num condoId,
    required num membershipId,
    String? reason,
  }) async {
    await api.send(
      'POST',
      '/manager/condominiums/$condoId/membership-requests/$membershipId/reject',
      body: {if (reason != null) 'reason': reason},
    );
  }

  // 0.2 FINANCEIRO DA UNIDADE & CONFIRMAÇÃO DE PAGAMENTO
  Future<List<Map<String, dynamic>>> getMyPayments(num condoId) async {
    final res = await api.get('/condominiums/$condoId/units/my-payments');
    return _asList(res);
  }

  Future<Map<String, dynamic>> requestPaymentConfirmation({
    required num condoId,
    required num unitId,
    required String note,
  }) async {
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/units/$unitId/request-payment-confirmation',
      body: {'note': note},
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> createSector({
    required num condoId,
    required String name,
    required String structuralType,
  }) async {
    await api.send(
      'POST',
      '/manager/condominiums/$condoId/sectors',
      body: {'name': name, 'structuralType': structuralType},
    );
  }

  Future<void> createUnit({
    required num condoId,
    required num sectorId,
    required String identifier,
  }) async {
    await api.send(
      'POST',
      '/manager/condominiums/$condoId/units',
      body: {'sectorId': sectorId, 'identifier': identifier},
    );
  }

  // 0.3 ENCOMENDAS PRÉ-CADASTRADAS & HISTÓRICO
  Future<Map<String, dynamic>> registerExpectedPackage({
    required num condoId,
    required num unitId,
    required String description,
    String? trackingCode,
    String? sender,
  }) async {
    final res = await api.send(
      'POST',
      '/packages/expected',
      body: {
        'condominiumId': condoId,
        'unitId': unitId,
        'description': description,
        if (trackingCode != null) 'trackingCode': trackingCode,
        if (sender != null) 'sender': sender,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> requestPackagePickup(num packageId) async {
    await api.send('POST', '/packages/$packageId/request-pickup');
  }

  // 1. OCORRÊNCIAS & CHAMADOS
  Future<List<Map<String, dynamic>>> listTickets(
    num condoId, {
    bool mine = false,
  }) async {
    final res = await api.get('/condominiums/$condoId/tickets?mine=$mine');
    return _asList(res);
  }

  Future<Map<String, dynamic>> createTicket({
    required num condoId,
    required String category,
    required String title,
    required String description,
    String? location,
    String? priority,
  }) async {
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/tickets',
      body: {
        'category': category,
        'title': title,
        'description': description,
        if (location != null) 'location': location,
        if (priority != null) 'priority': priority,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> updateTicketStatus({
    required num ticketId,
    required String status,
    String? adminResponse,
  }) async {
    await api.send(
      'PATCH',
      '/tickets/$ticketId/status',
      body: {
        'status': status,
        if (adminResponse != null) 'adminResponse': adminResponse,
      },
    );
  }

  // 2. VISITANTES & PRE-AUTORIZAÇÃO
  Future<List<Map<String, dynamic>>> listVisitors(
    num condoId, {
    bool mine = false,
  }) async {
    final res = await api.get('/condominiums/$condoId/visitors?mine=$mine');
    return _asList(res);
  }

  Future<Map<String, dynamic>> createVisitor({
    required num condoId,
    required String visitorName,
    String? documentNumber,
    String? visitorType,
    String? vehiclePlate,
    String? expectedDate,
    String? validFrom,
    String? validUntil,
    String? notes,
  }) async {
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/visitors',
      body: {
        'visitorName': visitorName,
        if (documentNumber != null) 'documentNumber': documentNumber,
        if (visitorType != null) 'visitorType': visitorType,
        if (vehiclePlate != null) 'vehiclePlate': vehiclePlate,
        if (expectedDate != null) 'expectedDate': expectedDate,
        if (validFrom != null) 'validFrom': validFrom,
        if (validUntil != null) 'validUntil': validUntil,
        if (notes != null) 'notes': notes,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> validateVisitorQr(
    num condoId, {
    required String qrCodeOrAccessCode,
    bool autoCheckIn = true,
  }) async {
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/visitors/validate-qr',
      body: {
        'qrCodeOrAccessCode': qrCodeOrAccessCode.trim(),
        'autoCheckIn': autoCheckIn,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> checkInVisitor(num id) async {
    await api.send('PATCH', '/visitors/$id/check-in');
  }

  Future<void> checkOutVisitor(num id) async {
    await api.send('PATCH', '/visitors/$id/check-out');
  }

  Future<void> denyVisitor(num id) async {
    await api.send('PATCH', '/visitors/$id/deny');
  }

  List<Map<String, dynamic>> _asList(dynamic data) {
    final List rawList;
    if (data is List) {
      rawList = data;
    } else if (data is Map && data['content'] is List) {
      rawList = data['content'] as List;
    } else {
      return [];
    }

    return rawList
        .map((item) {
          if (item is Map<String, dynamic>) {
            return item;
          } else if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
          return null;
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }
}
