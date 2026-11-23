part of 'community_api.dart';

extension CommunityApiCommunityExtension on CommunityApi {
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
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/polls',
      body: {
        'title': title,
        'description': description,
        'options': options,
        if (endsAt != null) 'endsAt': endsAt.toIso8601String(),
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> votePoll({
    required num pollId,
    required num optionId,
  }) async {
    final res = await api.send(
      'POST',
      '/polls/$pollId/vote',
      body: {'optionId': optionId},
    );
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
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/lost-found',
      body: {
        'type': type,
        'title': title,
        'description': description,
        if (category != null && category.isNotEmpty) 'category': category,
        if (location != null) 'location': location,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> claimLostFound(num id) async {
    await api.send('PATCH', '/lost-found/$id/request-claim');
  }

  Future<void> returnLostFound(num id) async {
    await api.send('PATCH', '/lost-found/$id/return');
  }

  Future<Map<String, dynamic>> closeLostFound(
    num id, {
    String? resolutionNotes,
  }) async {
    final res = await api.send(
      'PATCH',
      '/lost-found/$id/close',
      body: {
        if (resolutionNotes != null && resolutionNotes.isNotEmpty)
          'resolutionNotes': resolutionNotes,
      },
    );
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
    final res = await api.send(
      'POST',
      '/lost-found/$id/messages',
      body: {
        'message': message,
        if (contactInfo != null && contactInfo.isNotEmpty)
          'contactInfo': contactInfo,
      },
    );
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
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/classifieds',
      body: {
        'category': category,
        'title': title,
        'description': description,
        if (price != null) 'price': price,
        if (contactPhone != null) 'contactPhone': contactPhone,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> sendClassifiedInterest(num id, String message) async {
    await api.send(
      'POST',
      '/classifieds/$id/interest',
      body: {'message': message},
    );
  }

  Future<void> updateClassifiedStatus(num id, String status) async {
    await api.send(
      'PATCH',
      '/classifieds/$id/status',
      body: {'status': status},
    );
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
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/parking-spots',
      body: {
        'code': code,
        if (spotType != null) 'spotType': spotType,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (unitId != null) 'unitId': unitId,
      },
    );
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
    final res = await api.send(
      'PUT',
      '/parking-spots/$spotId',
      body: {
        if (code != null) 'code': code,
        if (spotType != null) 'spotType': spotType,
        if (description != null) 'description': description,
        if (unitId != null) 'unitId': unitId,
        if (status != null) 'status': status,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> deleteParkingSpot(num spotId) async {
    await api.send('DELETE', '/parking-spots/$spotId');
  }

  Future<List<Map<String, dynamic>>> listVehicles(
    num condoId, {
    bool mine = false,
  }) async {
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
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/vehicles',
      body: {
        'type': type,
        'brandModel': brandModel,
        'color': color,
        'licensePlate': licensePlate,
        if (parkingSpot != null) 'parkingSpot': parkingSpot,
        if (parkingSpotId != null) 'parkingSpotId': parkingSpotId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> checkPlate(num condoId, String plate) async {
    final p = Uri.encodeComponent(plate.trim());
    final res = await api.get(
      '/condominiums/$condoId/vehicles/check-plate?plate=$p',
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> approveVehicle(num id) async {
    await api.send('PATCH', '/vehicles/$id/approve');
  }

  Future<void> rejectVehicle(num id, [String? notes]) async {
    await api.send(
      'PATCH',
      '/vehicles/$id/reject',
      body: {if (notes != null && notes.isNotEmpty) 'notes': notes},
    );
  }

  Future<void> deleteVehicle(num id) async {
    await api.send('DELETE', '/vehicles/$id');
  }

  // 7. CENSO DE PETS
  Future<List<Map<String, dynamic>>> listPets(
    num condoId, {
    bool mine = false,
  }) async {
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
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/pets',
      body: {
        'name': name,
        'species': species,
        if (breed != null) 'breed': breed,
        if (size != null) 'size': size,
        if (color != null && color.isNotEmpty) 'color': color,
        'vaccinated': vaccinated,
        if (lastVaccinationDate != null && lastVaccinationDate.isNotEmpty)
          'lastVaccinationDate': lastVaccinationDate,
        if (notes != null) 'notes': notes,
      },
    );
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
    final res = await api.send(
      'PUT',
      '/pets/$id',
      body: {
        if (name != null) 'name': name,
        if (species != null) 'species': species,
        if (breed != null) 'breed': breed,
        if (size != null) 'size': size,
        if (color != null) 'color': color,
        if (vaccinated != null) 'vaccinated': vaccinated,
        if (lastVaccinationDate != null)
          'lastVaccinationDate': lastVaccinationDate,
        if (notes != null) 'notes': notes,
        if (managerNotes != null) 'managerNotes': managerNotes,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> deletePet(num id) async {
    await api.send('DELETE', '/pets/$id');
  }

  // 8. AGENDAMENTO DE MUDANÇAS E CARGAS PESADAS
  Future<Map<String, dynamic>> checkMovingAvailability(
    num condoId,
    DateTime date,
  ) async {
    final d =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final res = await api.get(
      '/condominiums/$condoId/moving-requests/check-availability?date=$d',
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listMovingRequests(
    num condoId, {
    bool mine = false,
  }) async {
    final res = await api.get(
      '/condominiums/$condoId/moving-requests?mine=$mine',
    );
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
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/moving-requests',
      body: {
        'type': type,
        'movingDate': movingDate,
        'period': period,
        if (companyName != null) 'companyName': companyName,
        if (contactPhone != null) 'contactPhone': contactPhone,
        if (notes != null) 'notes': notes,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> approveMovingRequest(num id) async {
    await api.send('PATCH', '/moving-requests/$id/approve');
  }

  Future<void> rejectMovingRequest(num id, [String? reason]) async {
    await api.send(
      'PATCH',
      '/moving-requests/$id/reject',
      body: {if (reason != null) 'reason': reason},
    );
  }

  Future<void> cancelMovingRequest(num id) async {
    await api.send('PATCH', '/moving-requests/$id/cancel');
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
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/documents',
      body: {
        'category': category,
        'title': title,
        if (summary != null) 'summary': summary,
        if (contentOrUrl != null) 'contentOrUrl': contentOrUrl,
        'pinned': pinned,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> deleteDocument(num id) async {
    await api.send('DELETE', '/documents/$id');
  }

  // 10. SMART LOCKERS & ARMÁRIOS INTELIGENTES
  Future<List<Map<String, dynamic>>> listLockers(
    num condoId, {
    bool mine = false,
  }) async {
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
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/lockers',
      body: {
        'compartmentNumber': compartmentNumber,
        'unitId': unitId,
        if (trackingCode != null) 'trackingCode': trackingCode,
        if (courierName != null) 'courierName': courierName,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> retrieveLocker(num id, [String? pinCode]) async {
    final res = await api.send(
      'PATCH',
      '/lockers/$id/retrieve',
      body: {if (pinCode != null && pinCode.isNotEmpty) 'pinCode': pinCode},
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  // 11. LISTAS DE CONVIDADOS DE EVENTOS
  Future<List<Map<String, dynamic>>> listGuestLists(
    num condoId, {
    bool mine = false,
  }) async {
    final res = await api.get('/condominiums/$condoId/guest-lists?mine=$mine');
    return _asList(res);
  }

  Future<Map<String, dynamic>> createGuestList({
    required num condoId,
    required String eventTitle,
    required String eventDate,
    String? notes,
    num? unitId,
    num? reservationId,
  }) async {
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/guest-lists',
      body: {
        'eventTitle': eventTitle,
        'eventDate': eventDate,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        if (unitId != null) 'unitId': unitId,
        if (reservationId != null) 'reservationId': reservationId,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> addGuest({
    required num guestListId,
    required String guestName,
    String? documentNumber,
  }) async {
    final res = await api.send(
      'POST',
      '/guest-lists/$guestListId/guests',
      body: {
        'guestName': guestName,
        if (documentNumber != null) 'documentNumber': documentNumber,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> checkInGuest(num guestId) async {
    await api.send('PATCH', '/guests/$guestId/check-in');
  }

  Future<void> removeGuest(num guestId) async {
    await api.send('DELETE', '/guests/$guestId');
  }

  // 12. INFRAÇÕES, ADVERTÊNCIAS E DEFESAS
  Future<List<Map<String, dynamic>>> listInfractions(
    num condoId, {
    bool mine = false,
  }) async {
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
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/infractions',
      body: {
        'unitId': unitId,
        'type': type,
        'title': title,
        'description': description,
        if (fineAmount != null) 'fineAmount': fineAmount,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> submitDefense(num infractionId, String defense) async {
    await api.send(
      'POST',
      '/infractions/$infractionId/defense',
      body: {'defense': defense},
    );
  }

  Future<void> judgeInfraction(
    num infractionId,
    String status,
    String judgment,
  ) async {
    await api.send(
      'PATCH',
      '/infractions/$infractionId/judge',
      body: {'status': status, 'judgment': judgment},
    );
  }

  // 13. CONTRAPROPOSTAS DE RESERVAS
  Future<void> counterProposeReservation({
    required num reservationId,
    required DateTime proposedStartAt,
    required DateTime proposedEndAt,
    String? notes,
  }) async {
    await api.send(
      'PATCH',
      '/reservations/$reservationId/counter-propose',
      body: {
        'proposedStartAt': proposedStartAt.toIso8601String(),
        'proposedEndAt': proposedEndAt.toIso8601String(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
  }

  Future<void> modifyAndConfirmReservation({
    required num reservationId,
    required DateTime startAt,
    required DateTime endAt,
    String? notes,
  }) async {
    await api.send(
      'PATCH',
      '/reservations/$reservationId/modify-and-confirm',
      body: {
        'startAt': startAt.toIso8601String(),
        'endAt': endAt.toIso8601String(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
  }

  Future<void> acceptCounterProposal(num reservationId) async {
    await api.send(
      'PATCH',
      '/reservations/$reservationId/accept-counter-proposal',
    );
  }

  Future<void> declineCounterProposal(num reservationId) async {
    await api.send(
      'PATCH',
      '/reservations/$reservationId/decline-counter-proposal',
    );
  }

  Future<List<Map<String, dynamic>>> getCondominiumReservations(
    num condoId,
  ) async {
    final res = await api.get('/condominiums/$condoId/reservations');
    return _asList(res);
  }

  // 14. CHAT EM TEMPO REAL COM A PORTARIA
  Future<List<Map<String, dynamic>>> getChatConversations(num condoId) async {
    final res = await api.get(
      '/condominiums/$condoId/doorman-chat/conversations',
    );
    return _asList(res);
  }

  Future<List<Map<String, dynamic>>> getChatMessages(
    num condoId, {
    num? targetUserId,
  }) async {
    final query = targetUserId != null ? '?targetUserId=$targetUserId' : '';
    final res = await api.get(
      '/condominiums/$condoId/doorman-chat/messages$query',
    );
    return _asList(res);
  }

  Future<Map<String, dynamic>> sendChatMessage(
    num condoId, {
    required String message,
    num? recipientId,
    num? unitId,
  }) async {
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/doorman-chat/messages',
      body: {
        'message': message,
        if (recipientId != null) 'recipientId': recipientId,
        if (unitId != null) 'unitId': unitId,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> markChatAsRead(num condoId) async {
    await api.send(
      'PATCH',
      '/condominiums/$condoId/doorman-chat/messages/read',
    );
  }

  // 15. GALERIA DE IMAGENS DO CONDOMÍNIO
  Future<List<Map<String, dynamic>>> getGalleryImages(num condoId) async {
    final res = await api.get('/condominiums/$condoId/gallery');
    return _asList(res);
  }

  Future<List<Map<String, dynamic>>> getAreaGalleryImages(
    num condoId,
    num areaId,
  ) async {
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
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/gallery',
      body: {
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        'image': image,
        if (commonAreaId != null) 'commonAreaId': commonAreaId,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> deleteGalleryImage(num condoId, num imageId) async {
    await api.send('DELETE', '/condominiums/$condoId/gallery/$imageId');
  }

}
