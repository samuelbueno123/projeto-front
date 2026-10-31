import '../../home/data/home_service.dart';

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
    final res = await api.get('/common-areas/$areaId/check-availability?startAt=$startStr&endAt=$endStr');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getAreaAvailability({
    required num areaId,
    required DateTime date,
  }) async {
    final dateStr = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final res = await api.get('/common-areas/$areaId/availability?date=$dateStr');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> requestReservation({
    required num areaId,
    required DateTime startAt,
    required DateTime endAt,
    required String contactPhone,
    String? notes,
  }) async {
    final res = await api.send('POST', '/common-areas/$areaId/reservations', body: {
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
      'contactPhone': contactPhone,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> approveReservation(num reservationId) async {
    await api.send('PATCH', '/reservations/$reservationId/approve');
  }

  Future<void> rejectReservation(num reservationId, [String? reason]) async {
    await api.send('PATCH', '/reservations/$reservationId/reject', body: {
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
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
    final res = await api.send('POST', '/condominiums/$condoId/membership-requests', body: {
      'authority': authority,
      if (unitId != null) 'unitId': unitId,
      if (residentType != null) 'residentType': residentType,
      if (message != null && message.isNotEmpty) 'message': message,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> approveMembershipRequest({
    required num condoId,
    required num membershipId,
    num? unitId,
    String? residentType,
  }) async {
    await api.send('POST', '/manager/condominiums/$condoId/membership-requests/$membershipId/approve', body: {
      if (unitId != null) 'unitId': unitId,
      if (residentType != null) 'residentType': residentType,
    });
  }

  Future<void> rejectMembershipRequest({
    required num condoId,
    required num membershipId,
    String? reason,
  }) async {
    await api.send('POST', '/manager/condominiums/$condoId/membership-requests/$membershipId/reject', body: {
      if (reason != null) 'reason': reason,
    });
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
    final res = await api.send('POST', '/condominiums/$condoId/units/$unitId/request-payment-confirmation', body: {
      'note': note,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> createSector({
    required num condoId,
    required String name,
    required String structuralType,
  }) async {
    await api.send('POST', '/manager/condominiums/$condoId/sectors', body: {
      'name': name,
      'structuralType': structuralType,
    });
  }

  Future<void> createUnit({
    required num condoId,
    required num sectorId,
    required String identifier,
  }) async {
    await api.send('POST', '/manager/condominiums/$condoId/units', body: {
      'sectorId': sectorId,
      'identifier': identifier,
    });
  }

  // 0.3 ENCOMENDAS PRÉ-CADASTRADAS & HISTÓRICO
  Future<Map<String, dynamic>> registerExpectedPackage({
    required num condoId,
    required num unitId,
    required String description,
    String? trackingCode,
    String? sender,
  }) async {
    final res = await api.send('POST', '/packages/expected', body: {
      'condominiumId': condoId,
      'unitId': unitId,
      'description': description,
      if (trackingCode != null) 'trackingCode': trackingCode,
      if (sender != null) 'sender': sender,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> requestPackagePickup(num packageId) async {
    await api.send('POST', '/packages/$packageId/request-pickup');
  }

  // 1. OCORRÊNCIAS & CHAMADOS
  Future<List<Map<String, dynamic>>> listTickets(num condoId, {bool mine = false}) async {
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
    final res = await api.send('POST', '/condominiums/$condoId/tickets', body: {
      'category': category,
      'title': title,
      'description': description,
      if (location != null) 'location': location,
      if (priority != null) 'priority': priority,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> updateTicketStatus({
    required num ticketId,
    required String status,
    String? adminResponse,
  }) async {
    await api.send('PATCH', '/tickets/$ticketId/status', body: {
      'status': status,
      if (adminResponse != null) 'adminResponse': adminResponse,
    });
  }

  // 2. VISITANTES & PRE-AUTORIZAÇÃO
  Future<List<Map<String, dynamic>>> listVisitors(num condoId, {bool mine = false}) async {
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
    String? notes,
  }) async {
    final res = await api.send('POST', '/condominiums/$condoId/visitors', body: {
      'visitorName': visitorName,
      if (documentNumber != null) 'documentNumber': documentNumber,
      if (visitorType != null) 'visitorType': visitorType,
      if (vehiclePlate != null) 'vehiclePlate': vehiclePlate,
      if (expectedDate != null) 'expectedDate': expectedDate,
      if (notes != null) 'notes': notes,
    });
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

  // 3. VOTAÇÕES & ENQUETES
  Future<List<Map<String, dynamic>>> listPolls(num condoId) async {
    final res = await api.get('/condominiums/$condoId/polls');
    return _asList(res);
  }

  Future<Map<String, dynamic>> createPoll({
    required num condoId,
    required String title,
    required String description,
    required List<String> options,
    DateTime? endsAt,
  }) async {
    final res = await api.send('POST', '/condominiums/$condoId/polls', body: {
      'title': title,
      'description': description,
      'options': options,
      if (endsAt != null) 'endsAt': endsAt.toIso8601String(),
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> votePoll({
    required num pollId,
    required num optionId,
  }) async {
    final res = await api.send('POST', '/polls/$pollId/vote', body: {
      'optionId': optionId,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> closePoll(num pollId) async {
    await api.send('PATCH', '/polls/$pollId/close');
  }

  // 4. ACHADOS E PERDIDOS
  Future<List<Map<String, dynamic>>> listLostFound(num condoId) async {
    final res = await api.get('/condominiums/$condoId/lost-found');
    return _asList(res);
  }

  Future<Map<String, dynamic>> createLostFound({
    required num condoId,
    required String type,
    required String title,
    required String description,
    String? location,
  }) async {
    final res = await api.send('POST', '/condominiums/$condoId/lost-found', body: {
      'type': type,
      'title': title,
      'description': description,
      if (location != null) 'location': location,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> claimLostFound(num id) async {
    await api.send('PATCH', '/lost-found/$id/request-claim');
  }

  Future<void> returnLostFound(num id) async {
    await api.send('PATCH', '/lost-found/$id/return');
  }

  // 5. CLASSIFICADOS INTERNOS
  Future<List<Map<String, dynamic>>> listClassifieds(num condoId) async {
    final res = await api.get('/condominiums/$condoId/classifieds');
    return _asList(res);
  }

  Future<Map<String, dynamic>> createClassified({
    required num condoId,
    required String category,
    required String title,
    required String description,
    String? price,
    String? contactPhone,
  }) async {
    final res = await api.send('POST', '/condominiums/$condoId/classifieds', body: {
      'category': category,
      'title': title,
      'description': description,
      if (price != null) 'price': price,
      if (contactPhone != null) 'contactPhone': contactPhone,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> sendClassifiedInterest(num id, String message) async {
    await api.send('POST', '/classifieds/$id/interest', body: {
      'message': message,
    });
  }

  Future<void> updateClassifiedStatus(num id, String status) async {
    await api.send('PATCH', '/classifieds/$id/status', body: {
      'status': status,
    });
  }

  // 6. VEÍCULOS & CONSULTA DE PLACAS
  Future<List<Map<String, dynamic>>> listVehicles(num condoId, {bool mine = false}) async {
    final res = await api.get('/condominiums/$condoId/vehicles?mine=$mine');
    return _asList(res);
  }

  Future<Map<String, dynamic>> createVehicle({
    required num condoId,
    required String type,
    required String brandModel,
    required String color,
    required String licensePlate,
    String? parkingSpot,
  }) async {
    final res = await api.send('POST', '/condominiums/$condoId/vehicles', body: {
      'type': type,
      'brandModel': brandModel,
      'color': color,
      'licensePlate': licensePlate,
      if (parkingSpot != null) 'parkingSpot': parkingSpot,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> checkPlate(num condoId, String plate) async {
    final p = Uri.encodeComponent(plate.trim());
    final res = await api.get('/condominiums/$condoId/vehicles/check-plate?plate=$p');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> approveVehicle(num id) async {
    await api.send('PATCH', '/vehicles/$id/approve');
  }

  Future<void> rejectVehicle(num id) async {
    await api.send('PATCH', '/vehicles/$id/reject');
  }

  // 7. CENSO DE PETS
  Future<List<Map<String, dynamic>>> listPets(num condoId, {bool mine = false}) async {
    final res = await api.get('/condominiums/$condoId/pets?mine=$mine');
    return _asList(res);
  }

  Future<Map<String, dynamic>> createPet({
    required num condoId,
    required String name,
    required String species,
    String? breed,
    String? size,
    bool vaccinated = true,
    String? notes,
  }) async {
    final res = await api.send('POST', '/condominiums/$condoId/pets', body: {
      'name': name,
      'species': species,
      if (breed != null) 'breed': breed,
      if (size != null) 'size': size,
      'vaccinated': vaccinated,
      if (notes != null) 'notes': notes,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> deletePet(num id) async {
    await api.send('DELETE', '/pets/$id');
  }

  // 8. AGENDAMENTO DE MUDANÇAS E CARGAS PESADAS
  Future<Map<String, dynamic>> checkMovingAvailability(num condoId, DateTime date) async {
    final d = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final res = await api.get('/condominiums/$condoId/moving-requests/check-availability?date=$d');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listMovingRequests(num condoId, {bool mine = false}) async {
    final res = await api.get('/condominiums/$condoId/moving-requests?mine=$mine');
    return _asList(res);
  }

  Future<Map<String, dynamic>> createMovingRequest({
    required num condoId,
    required String type,
    required String movingDate,
    required String period,
    String? companyName,
    String? contactPhone,
    String? notes,
  }) async {
    final res = await api.send('POST', '/condominiums/$condoId/moving-requests', body: {
      'type': type,
      'movingDate': movingDate,
      'period': period,
      if (companyName != null) 'companyName': companyName,
      if (contactPhone != null) 'contactPhone': contactPhone,
      if (notes != null) 'notes': notes,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> approveMovingRequest(num id) async {
    await api.send('PATCH', '/moving-requests/$id/approve');
  }

  Future<void> rejectMovingRequest(num id, [String? reason]) async {
    await api.send('PATCH', '/moving-requests/$id/reject', body: {
      if (reason != null) 'reason': reason,
    });
  }

  // 9. REPOSITÓRIO DE DOCUMENTOS, ATAS E CONTATOS
  Future<List<Map<String, dynamic>>> listDocuments(num condoId) async {
    final res = await api.get('/condominiums/$condoId/documents');
    return _asList(res);
  }

  Future<Map<String, dynamic>> createDocument({
    required num condoId,
    required String category,
    required String title,
    String? summary,
    String? contentOrUrl,
    bool pinned = false,
  }) async {
    final res = await api.send('POST', '/condominiums/$condoId/documents', body: {
      'category': category,
      'title': title,
      if (summary != null) 'summary': summary,
      if (contentOrUrl != null) 'contentOrUrl': contentOrUrl,
      'pinned': pinned,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> deleteDocument(num id) async {
    await api.send('DELETE', '/documents/$id');
  }

  // 10. SMART LOCKERS & ARMÁRIOS INTELIGENTES
  Future<List<Map<String, dynamic>>> listLockers(num condoId, {bool mine = false}) async {
    final res = await api.get('/condominiums/$condoId/lockers?mine=$mine');
    return _asList(res);
  }

  Future<Map<String, dynamic>> depositLocker({
    required num condoId,
    required String compartmentNumber,
    required num unitId,
    String? trackingCode,
    String? courierName,
  }) async {
    final res = await api.send('POST', '/condominiums/$condoId/lockers', body: {
      'compartmentNumber': compartmentNumber,
      'unitId': unitId,
      if (trackingCode != null) 'trackingCode': trackingCode,
      if (courierName != null) 'courierName': courierName,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> retrieveLocker(num id, [String? pinCode]) async {
    final res = await api.send('PATCH', '/lockers/$id/retrieve', body: {
      if (pinCode != null && pinCode.isNotEmpty) 'pinCode': pinCode,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  // 11. LISTAS DE CONVIDADOS DE EVENTOS
  Future<List<Map<String, dynamic>>> listGuestLists(num condoId, {bool mine = false}) async {
    final res = await api.get('/condominiums/$condoId/guest-lists?mine=$mine');
    return _asList(res);
  }

  Future<Map<String, dynamic>> createGuestList({
    required num condoId,
    required String eventTitle,
    required String eventDate,
    num? unitId,
    num? reservationId,
  }) async {
    final res = await api.send('POST', '/condominiums/$condoId/guest-lists', body: {
      'eventTitle': eventTitle,
      'eventDate': eventDate,
      if (unitId != null) 'unitId': unitId,
      if (reservationId != null) 'reservationId': reservationId,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> addGuest({
    required num guestListId,
    required String guestName,
    String? documentNumber,
  }) async {
    final res = await api.send('POST', '/guest-lists/$guestListId/guests', body: {
      'guestName': guestName,
      if (documentNumber != null) 'documentNumber': documentNumber,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> checkInGuest(num guestId) async {
    await api.send('PATCH', '/guests/$guestId/check-in');
  }

  Future<void> removeGuest(num guestId) async {
    await api.send('DELETE', '/guests/$guestId');
  }

  // 12. INFRAÇÕES, ADVERTÊNCIAS E DEFESAS
  Future<List<Map<String, dynamic>>> listInfractions(num condoId, {bool mine = false}) async {
    final res = await api.get('/condominiums/$condoId/infractions?mine=$mine');
    return _asList(res);
  }

  Future<Map<String, dynamic>> createInfraction({
    required num condoId,
    required num unitId,
    required String type,
    required String title,
    required String description,
    String? fineAmount,
  }) async {
    final res = await api.send('POST', '/condominiums/$condoId/infractions', body: {
      'unitId': unitId,
      'type': type,
      'title': title,
      'description': description,
      if (fineAmount != null) 'fineAmount': fineAmount,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> submitDefense(num infractionId, String defense) async {
    await api.send('POST', '/infractions/$infractionId/defense', body: {
      'defense': defense,
    });
  }

  Future<void> judgeInfraction(num infractionId, String status, String judgment) async {
    await api.send('PATCH', '/infractions/$infractionId/judge', body: {
      'status': status,
      'judgment': judgment,
    });
  }

  List<Map<String, dynamic>> _asList(dynamic data) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map && data['content'] is List) {
      return (data['content'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }
}
