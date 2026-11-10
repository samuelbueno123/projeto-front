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

  Future<Map<String, dynamic>> joinWaitlist({
    required num areaId,
    required DateTime startAt,
    required DateTime endAt,
    required String contactPhone,
    String? notes,
  }) async {
    final res = await api.send('POST', '/common-areas/$areaId/waitlist', body: {
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
      'contactPhone': contactPhone,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getAreaWaitlist(num areaId) async {
    final res = await api.get('/common-areas/$areaId/waitlist');
    return _asList(res);
  }

  // 0.05 CONFIRMAÇÃO DE LEITURA DE COMUNICADOS
  Future<Map<String, dynamic>> markAnnouncementAsRead(num announcementId) async {
    final res = await api.send('POST', '/announcements/$announcementId/read');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getAnnouncementReaders(num announcementId) async {
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
    String? validFrom,
    String? validUntil,
    String? notes,
  }) async {
    final res = await api.send('POST', '/condominiums/$condoId/visitors', body: {
      'visitorName': visitorName,
      if (documentNumber != null) 'documentNumber': documentNumber,
      if (visitorType != null) 'visitorType': visitorType,
      if (vehiclePlate != null) 'vehiclePlate': vehiclePlate,
      if (expectedDate != null) 'expectedDate': expectedDate,
      if (validFrom != null) 'validFrom': validFrom,
      if (validUntil != null) 'validUntil': validUntil,
      if (notes != null) 'notes': notes,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> validateVisitorQr(
    num condoId, {
    required String qrCodeOrAccessCode,
    bool autoCheckIn = true,
  }) async {
    final res = await api.send('POST', '/condominiums/$condoId/visitors/validate-qr', body: {
      'qrCodeOrAccessCode': qrCodeOrAccessCode.trim(),
      'autoCheckIn': autoCheckIn,
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
    String? category,
    String? location,
    String? imageUrl,
  }) async {
    final res = await api.send('POST', '/condominiums/$condoId/lost-found', body: {
      'type': type,
      'title': title,
      'description': description,
      if (category != null && category.isNotEmpty) 'category': category,
      if (location != null) 'location': location,
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> claimLostFound(num id) async {
    await api.send('PATCH', '/lost-found/$id/request-claim');
  }

  Future<void> returnLostFound(num id) async {
    await api.send('PATCH', '/lost-found/$id/return');
  }

  Future<Map<String, dynamic>> closeLostFound(num id, {String? resolutionNotes}) async {
    final res = await api.send('PATCH', '/lost-found/$id/close', body: {
      if (resolutionNotes != null && resolutionNotes.isNotEmpty) 'resolutionNotes': resolutionNotes,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listLostFoundMessages(num id) async {
    final res = await api.get('/lost-found/$id/messages');
    return _asList(res);
  }

  Future<Map<String, dynamic>> addLostFoundMessage(
    num id, {
    required String message,
    String? contactInfo,
  }) async {
    final res = await api.send('POST', '/lost-found/$id/messages', body: {
      'message': message,
      if (contactInfo != null && contactInfo.isNotEmpty) 'contactInfo': contactInfo,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
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

  // 6. VEÍCULOS, VAGAS DE GARAGEM & CONSULTA DE PLACAS
  Future<List<Map<String, dynamic>>> listParkingSpots(num condoId) async {
    final res = await api.get('/condominiums/$condoId/parking-spots');
    return _asList(res);
  }

  Future<Map<String, dynamic>> createParkingSpot({
    required num condoId,
    required String code,
    String? spotType,
    String? description,
    num? unitId,
  }) async {
    final res = await api.send('POST', '/condominiums/$condoId/parking-spots', body: {
      'code': code,
      if (spotType != null) 'spotType': spotType,
      if (description != null && description.isNotEmpty) 'description': description,
      if (unitId != null) 'unitId': unitId,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateParkingSpot(
    num spotId, {
    String? code,
    String? spotType,
    String? description,
    num? unitId,
    String? status,
  }) async {
    final res = await api.send('PUT', '/parking-spots/$spotId', body: {
      if (code != null) 'code': code,
      if (spotType != null) 'spotType': spotType,
      if (description != null) 'description': description,
      if (unitId != null) 'unitId': unitId,
      if (status != null) 'status': status,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> deleteParkingSpot(num spotId) async {
    await api.send('DELETE', '/parking-spots/$spotId');
  }

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
    num? parkingSpotId,
    String? notes,
  }) async {
    final res = await api.send('POST', '/condominiums/$condoId/vehicles', body: {
      'type': type,
      'brandModel': brandModel,
      'color': color,
      'licensePlate': licensePlate,
      if (parkingSpot != null) 'parkingSpot': parkingSpot,
      if (parkingSpotId != null) 'parkingSpotId': parkingSpotId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
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

  Future<void> rejectVehicle(num id, [String? notes]) async {
    await api.send('PATCH', '/vehicles/$id/reject', body: {
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
  }

  Future<void> deleteVehicle(num id) async {
    await api.send('DELETE', '/vehicles/$id');
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
    String? color,
    bool vaccinated = true,
    String? lastVaccinationDate,
    String? notes,
  }) async {
    final res = await api.send('POST', '/condominiums/$condoId/pets', body: {
      'name': name,
      'species': species,
      if (breed != null) 'breed': breed,
      if (size != null) 'size': size,
      if (color != null && color.isNotEmpty) 'color': color,
      'vaccinated': vaccinated,
      if (lastVaccinationDate != null && lastVaccinationDate.isNotEmpty)
        'lastVaccinationDate': lastVaccinationDate,
      if (notes != null) 'notes': notes,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updatePet(
    num id, {
    String? name,
    String? species,
    String? breed,
    String? size,
    String? color,
    bool? vaccinated,
    String? lastVaccinationDate,
    String? notes,
    String? managerNotes,
  }) async {
    final res = await api.send('PUT', '/pets/$id', body: {
      if (name != null) 'name': name,
      if (species != null) 'species': species,
      if (breed != null) 'breed': breed,
      if (size != null) 'size': size,
      if (color != null) 'color': color,
      if (vaccinated != null) 'vaccinated': vaccinated,
      if (lastVaccinationDate != null) 'lastVaccinationDate': lastVaccinationDate,
      if (notes != null) 'notes': notes,
      if (managerNotes != null) 'managerNotes': managerNotes,
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

  
  // 13. CONTRAPROPOSTAS DE RESERVAS
  Future<void> counterProposeReservation({
    required num reservationId,
    required DateTime proposedStartAt,
    required DateTime proposedEndAt,
    String? notes,
  }) async {
    await api.send('PATCH', '/reservations/$reservationId/counter-propose', body: {
      'proposedStartAt': proposedStartAt.toIso8601String(),
      'proposedEndAt': proposedEndAt.toIso8601String(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
  }

  Future<void> modifyAndConfirmReservation({
    required num reservationId,
    required DateTime startAt,
    required DateTime endAt,
    String? notes,
  }) async {
    await api.send('PATCH', '/reservations/$reservationId/modify-and-confirm', body: {
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
  }

  Future<void> acceptCounterProposal(num reservationId) async {
    await api.send('PATCH', '/reservations/$reservationId/accept-counter-proposal');
  }

  Future<void> declineCounterProposal(num reservationId) async {
    await api.send('PATCH', '/reservations/$reservationId/decline-counter-proposal');
  }

  Future<List<Map<String, dynamic>>> getCondominiumReservations(num condoId) async {
    final res = await api.get('/condominiums/$condoId/reservations');
    return _asList(res);
  }

  // 14. CHAT EM TEMPO REAL COM A PORTARIA
  Future<List<Map<String, dynamic>>> getChatConversations(num condoId) async {
    final res = await api.get('/condominiums/$condoId/doorman-chat/conversations');
    return _asList(res);
  }

  Future<List<Map<String, dynamic>>> getChatMessages(num condoId, {num? targetUserId}) async {
    final query = targetUserId != null ? '?targetUserId=$targetUserId' : '';
    final res = await api.get('/condominiums/$condoId/doorman-chat/messages$query');
    return _asList(res);
  }

  Future<Map<String, dynamic>> sendChatMessage(
    num condoId, {
    required String message,
    num? recipientId,
    num? unitId,
  }) async {
    final res = await api.send('POST', '/condominiums/$condoId/doorman-chat/messages', body: {
      'message': message,
      if (recipientId != null) 'recipientId': recipientId,
      if (unitId != null) 'unitId': unitId,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> markChatAsRead(num condoId) async {
    await api.send('PATCH', '/condominiums/$condoId/doorman-chat/messages/read');
  }

  // 15. GALERIA DE IMAGENS DO CONDOMÍNIO
  Future<List<Map<String, dynamic>>> getGalleryImages(num condoId) async {
    final res = await api.get('/condominiums/$condoId/gallery');
    return _asList(res);
  }

  Future<List<Map<String, dynamic>>> getAreaGalleryImages(num condoId, num areaId) async {
    final res = await api.get('/condominiums/$condoId/gallery/area/$areaId');
    return _asList(res);
  }

  Future<Map<String, dynamic>> addGalleryImage(
    num condoId, {
    required String title,
    String? description,
    required String image,
    num? commonAreaId,
  }) async {
    final res = await api.send('POST', '/condominiums/$condoId/gallery', body: {
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      'image': image,
      if (commonAreaId != null) 'commonAreaId': commonAreaId,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> deleteGalleryImage(num condoId, num imageId) async {
    await api.send('DELETE', '/condominiums/$condoId/gallery/$imageId');
  }

  // 16. BOLETOS E COBRANÇAS CONDOMINIAIS
  Future<List<Map<String, dynamic>>> getMyInvoices(num condoId) async {
    final res = await api.get('/condominiums/$condoId/my-invoices');
    return _asList(res);
  }

  Future<Map<String, dynamic>> getUnitPaymentStatus(num condoId, num unitId) async {
    final res = await api.get('/condominiums/$condoId/units/$unitId/payment-status');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> generateBoleto(
    num condoId,
    num unitId, {
    required double amount,
    required DateTime dueDate,
    required String title,
  }) async {
    final dateStr = '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
    final res = await api.send('POST', '/manager/condominiums/$condoId/units/$unitId/generate-boleto', body: {
      'amount': amount,
      'dueDate': dateStr,
      'title': title,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> payBoleto(num condoId, num unitId) async {
    final res = await api.send('POST', '/condominiums/$condoId/units/$unitId/pay-boleto');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  // 17. ONBOARDING DE PLANOS & BOAS-VINDAS
  Future<List<Map<String, dynamic>>> getBillingPlans() async {
    final res = await api.get('/billing/plans');
    return _asList(res);
  }

  Future<Map<String, dynamic>> selectCondominiumPlan(num condoId, num planId) async {
    final res = await api.send('PUT', '/manager/condominiums/$condoId/select-plan', body: {
      'planId': planId,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> acknowledgeWelcome(num membershipId) async {
    await api.send('POST', '/memberships/$membershipId/ack-welcome');
  }

  // 18. TEMA DO USUÁRIO
  Future<void> updateThemePreference(String theme) async {
    await api.send('PATCH', '/users/me/theme', body: {'theme': theme});
  }

  // 19. GESTÃO FINANCEIRA E DESPESAS
  Future<Map<String, dynamic>> getFinancialSummary(num condoId) async {
    final res = await api.get('/condominiums/$condoId/financial/summary');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listExpenses(num condoId) async {
    final res = await api.get('/condominiums/$condoId/financial/expenses');
    return _asList(res);
  }

  Future<Map<String, dynamic>> createExpense(
    num condoId, {
    required String category,
    required String description,
    required double amount,
    required DateTime dueDate,
    String? supplier,
    String? documentNumber,
    String? receiptUrl,
  }) async {
    final dateStr = '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
    final res = await api.send('POST', '/condominiums/$condoId/financial/expenses', body: {
      'category': category,
      'description': description,
      'amount': amount,
      'dueDate': dateStr,
      if (supplier != null && supplier.isNotEmpty) 'supplier': supplier,
      if (documentNumber != null && documentNumber.isNotEmpty) 'documentNumber': documentNumber,
      if (receiptUrl != null && receiptUrl.isNotEmpty) 'receiptUrl': receiptUrl,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> payExpense(num expenseId) async {
    final res = await api.send('PATCH', '/financial/expenses/$expenseId/pay');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> cancelExpense(num expenseId) async {
    final res = await api.send('PATCH', '/financial/expenses/$expenseId/cancel');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  // 20. MANUTENÇÃO PREDIAL E ORDENS DE SERVIÇO
  Future<List<Map<String, dynamic>>> listMaintenanceOrders(num condoId, [String? status]) async {
    final query = status != null && status.isNotEmpty ? '?status=$status' : '';
    final res = await api.get('/condominiums/$condoId/maintenance/orders$query');
    return _asList(res);
  }

  Future<Map<String, dynamic>> getMaintenanceOrder(num id) async {
    final res = await api.get('/maintenance/orders/$id');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createMaintenanceOrder(
    num condoId, {
    required String title,
    required String description,
    required String category,
    String? type,
    String? priority,
    String? contractorName,
    String? contractorContact,
    num? equipmentId,
    num? supplierId,
    DateTime? scheduledDate,
    double? estimatedCost,
    String? notes,
  }) async {
    final dateStr = scheduledDate != null
        ? '${scheduledDate.year.toString().padLeft(4, '0')}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}'
        : null;
    final res = await api.send('POST', '/condominiums/$condoId/maintenance/orders', body: {
      'title': title,
      'description': description,
      'category': category,
      if (type != null) 'type': type,
      if (priority != null) 'priority': priority,
      if (contractorName != null) 'contractorName': contractorName,
      if (contractorContact != null) 'contractorContact': contractorContact,
      if (equipmentId != null) 'equipmentId': equipmentId,
      if (supplierId != null) 'supplierId': supplierId,
      if (dateStr != null) 'scheduledDate': dateStr,
      if (estimatedCost != null) 'estimatedCost': estimatedCost,
      if (notes != null) 'notes': notes,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateMaintenanceOrderStatus(
    num id, {
    required String status,
    double? actualCost,
    String? notes,
    int? supplierRating,
    String? supplierFeedback,
  }) async {
    final res = await api.send('PATCH', '/maintenance/orders/$id/status', body: {
      'status': status,
      if (actualCost != null) 'actualCost': actualCost,
      if (notes != null) 'notes': notes,
      if (supplierRating != null) 'supplierRating': supplierRating,
      if (supplierFeedback != null && supplierFeedback.isNotEmpty) 'supplierFeedback': supplierFeedback,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listMaintenanceEquipment(num condoId) async {
    final res = await api.get('/condominiums/$condoId/maintenance/equipment');
    return _asList(res);
  }

  Future<Map<String, dynamic>> createMaintenanceEquipment(
    num condoId, {
    required String name,
    required String category,
    String? location,
    String? manufacturer,
    int recurrenceDays = 30,
    String? nextMaintenanceDate,
    String? responsibleName,
    num? preferredSupplierId,
    String? notes,
  }) async {
    final res = await api.send('POST', '/condominiums/$condoId/maintenance/equipment', body: {
      'name': name,
      'category': category,
      if (location != null && location.isNotEmpty) 'location': location,
      if (manufacturer != null && manufacturer.isNotEmpty) 'manufacturer': manufacturer,
      'recurrenceDays': recurrenceDays,
      if (nextMaintenanceDate != null && nextMaintenanceDate.isNotEmpty)
        'nextMaintenanceDate': nextMaintenanceDate,
      if (responsibleName != null && responsibleName.isNotEmpty)
        'responsibleName': responsibleName,
      if (preferredSupplierId != null) 'preferredSupplierId': preferredSupplierId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> deleteMaintenanceEquipment(num id) async {
    await api.send('DELETE', '/maintenance/equipment/$id');
  }

  Future<List<Map<String, dynamic>>> listSuppliers(num condoId) async {
    final res = await api.get('/condominiums/$condoId/suppliers');
    return _asList(res);
  }

  Future<Map<String, dynamic>> createSupplier(
    num condoId, {
    required String companyName,
    required String serviceCategory,
    String? contactName,
    String? phone,
    String? email,
    String? documentNumber,
    String? notes,
  }) async {
    final res = await api.send('POST', '/condominiums/$condoId/suppliers', body: {
      'companyName': companyName,
      'serviceCategory': serviceCategory,
      if (contactName != null && contactName.isNotEmpty) 'contactName': contactName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
      if (documentNumber != null && documentNumber.isNotEmpty) 'documentNumber': documentNumber,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> deleteSupplier(num id) async {
    await api.send('DELETE', '/suppliers/$id');
  }

  // 21. ASSEMBLEIAS E VOTAÇÃO DE PAUTAS
  Future<List<Map<String, dynamic>>> listAssemblies(num condoId) async {
    final res = await api.get('/condominiums/$condoId/assemblies');
    return _asList(res);
  }

  Future<Map<String, dynamic>> getAssembly(num id) async {
    final res = await api.get('/assemblies/$id');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createAssembly(
    num condoId, {
    required String title,
    String? description,
    String? type,
    required DateTime meetingDate,
    DateTime? secondCallDate,
    String? locationOrLink,
    String? callNoticeUrl,
    bool blockDelinquentUnits = false,
    bool oneVotePerUnit = true,
    int quorumMinimumPercent = 50,
  }) async {
    final res = await api.send('POST', '/condominiums/$condoId/assemblies', body: {
      'title': title,
      if (description != null) 'description': description,
      if (type != null) 'type': type,
      'meetingDate': meetingDate.toIso8601String(),
      if (secondCallDate != null) 'secondCallDate': secondCallDate.toIso8601String(),
      if (locationOrLink != null) 'locationOrLink': locationOrLink,
      if (callNoticeUrl != null) 'callNoticeUrl': callNoticeUrl,
      'blockDelinquentUnits': blockDelinquentUnits,
      'oneVotePerUnit': oneVotePerUnit,
      'quorumMinimumPercent': quorumMinimumPercent,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> checkInAssembly(num assemblyId, {String? proxyInfo}) async {
    final res = await api.send('POST', '/assemblies/$assemblyId/check-in', body: {
      if (proxyInfo != null && proxyInfo.isNotEmpty) 'proxyInfo': proxyInfo,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listAssemblyParticipants(num assemblyId) async {
    final res = await api.get('/assemblies/$assemblyId/participants');
    return _asList(res);
  }

  Future<Map<String, dynamic>> addAssemblyTopic(
    num assemblyId, {
    required String title,
    String? description,
    int? displayOrder,
  }) async {
    final res = await api.send('POST', '/assemblies/$assemblyId/topics', body: {
      'title': title,
      if (description != null) 'description': description,
      if (displayOrder != null) 'displayOrder': displayOrder,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> toggleAssemblyTopicVoting(num topicId, bool open) async {
    final res = await api.send('PATCH', '/assembly-topics/$topicId/voting?open=$open');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> castAssemblyVote(num topicId, String voteChoice) async {
    final res = await api.send('POST', '/assembly-topics/$topicId/votes', body: {
      'voteChoice': voteChoice,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateAssemblyStatus(
    num id, {
    required String status,
    String? minutesUrl,
  }) async {
    final res = await api.send('PATCH', '/assemblies/$id/status', body: {
      'status': status,
      if (minutesUrl != null) 'minutesUrl': minutesUrl,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  // 22. ASSISTENTE INTELIGENTE CONDOMINIAL & RELATÓRIOS GERENCIAIS
  Future<Map<String, dynamic>> askAssistant(num condoId, String question, [String? category]) async {
    final res = await api.send('POST', '/condominiums/$condoId/assistant/query', body: {
      'question': question,
      if (category != null) 'category': category,
    });
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getDashboardReport(
    num condoId, {
    String? startDate,
    String? endDate,
  }) async {
    final params = <String>[];
    if (startDate != null && startDate.isNotEmpty) params.add('startDate=$startDate');
    if (endDate != null && endDate.isNotEmpty) params.add('endDate=$endDate');
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final res = await api.get('/condominiums/$condoId/reports/dashboard$query');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
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

    return rawList.map((item) {
      if (item is Map<String, dynamic>) {
        return item;
      } else if (item is Map) {
        return Map<String, dynamic>.from(item);
      }
      return null;
    }).whereType<Map<String, dynamic>>().toList();
  }
}
