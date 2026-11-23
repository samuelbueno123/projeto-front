part of 'community_api.dart';

extension CommunityApiGovernanceExtension on CommunityApi {
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
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/assemblies',
      body: {
        'title': title,
        if (description != null) 'description': description,
        if (type != null) 'type': type,
        'meetingDate': meetingDate.toIso8601String(),
        if (secondCallDate != null)
          'secondCallDate': secondCallDate.toIso8601String(),
        if (locationOrLink != null) 'locationOrLink': locationOrLink,
        if (callNoticeUrl != null) 'callNoticeUrl': callNoticeUrl,
        'blockDelinquentUnits': blockDelinquentUnits,
        'oneVotePerUnit': oneVotePerUnit,
        'quorumMinimumPercent': quorumMinimumPercent,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> checkInAssembly(
    num assemblyId, {
    String? proxyInfo,
  }) async {
    final res = await api.send(
      'POST',
      '/assemblies/$assemblyId/check-in',
      body: {
        if (proxyInfo != null && proxyInfo.isNotEmpty) 'proxyInfo': proxyInfo,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listAssemblyParticipants(
    num assemblyId,
  ) async {
    final res = await api.get('/assemblies/$assemblyId/participants');
    return _asList(res);
  }

  Future<Map<String, dynamic>> addAssemblyTopic(
    num assemblyId, {
    required String title,
    String? description,
    int? displayOrder,
  }) async {
    final res = await api.send(
      'POST',
      '/assemblies/$assemblyId/topics',
      body: {
        'title': title,
        if (description != null) 'description': description,
        if (displayOrder != null) 'displayOrder': displayOrder,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> toggleAssemblyTopicVoting(
    num topicId,
    bool open,
  ) async {
    final res = await api.send(
      'PATCH',
      '/assembly-topics/$topicId/voting?open=$open',
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> castAssemblyVote(
    num topicId,
    String voteChoice,
  ) async {
    final res = await api.send(
      'POST',
      '/assembly-topics/$topicId/votes',
      body: {'voteChoice': voteChoice},
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateAssemblyStatus(
    num id, {
    required String status,
    String? minutesUrl,
  }) async {
    final res = await api.send(
      'PATCH',
      '/assemblies/$id/status',
      body: {
        'status': status,
        if (minutesUrl != null) 'minutesUrl': minutesUrl,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  // 22. ASSISTENTE INTELIGENTE CONDOMINIAL & RELATÓRIOS GERENCIAIS
  Future<Map<String, dynamic>> askAssistant(
    num condoId,
    String question, [
    String? category,
  ]) async {
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/assistant/query',
      body: {'question': question, if (category != null) 'category': category},
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getDashboardReport(
    num condoId, {
    String? startDate,
    String? endDate,
  }) async {
    final params = <String>[];
    if (startDate != null && startDate.isNotEmpty) {
      params.add('startDate=$startDate');
    }
    if (endDate != null && endDate.isNotEmpty) params.add('endDate=$endDate');
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final res = await api.get('/condominiums/$condoId/reports/dashboard$query');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Uint8List> downloadDashboardReportPdf(
    num condoId, {
    String? startDate,
    String? endDate,
  }) {
    return api.getBytes(
      '/condominiums/$condoId/reports/export/pdf',
      queryParameters: {
        if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
      },
    );
  }

  Future<Uint8List> downloadDashboardReportCsv(
    num condoId, {
    String? startDate,
    String? endDate,
  }) {
    return api.getBytes(
      '/condominiums/$condoId/reports/export/csv',
      queryParameters: {
        if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
      },
    );
  }

  // 13. OBRAS E REFORMAS (NBR 16.280)
  Future<List<Map<String, dynamic>>> getRenovations(
    num condoId, {
    bool mine = false,
  }) async {
    final res = await api.get('/condominiums/$condoId/renovations?mine=$mine');
    return _asList(res);
  }

  Future<Map<String, dynamic>> requestRenovation(
    num condoId,
    Map<String, dynamic> body,
  ) async {
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/renovations',
      body: body,
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> approveRenovation(num id, {String? decisionNotes}) async {
    await api.send(
      'PATCH',
      '/renovations/$id/approve',
      body: {if (decisionNotes != null) 'decisionNotes': decisionNotes},
    );
  }

  Future<void> rejectRenovation(num id, {String? decisionNotes}) async {
    await api.send(
      'PATCH',
      '/renovations/$id/reject',
      body: {if (decisionNotes != null) 'decisionNotes': decisionNotes},
    );
  }

  Future<void> completeRenovation(num id) async {
    await api.send('PATCH', '/renovations/$id/complete');
  }

  // 14. LIVRO DIGITAL DE PASSAGEM DE TURNO DA PORTARIA
  Future<List<Map<String, dynamic>>> getShiftLogs(num condoId) async {
    final res = await api.get('/condominiums/$condoId/shift-logs');
    return _asList(res);
  }

  Future<Map<String, dynamic>> createShiftLog(
    num condoId,
    Map<String, dynamic> body,
  ) async {
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/shift-logs',
      body: body,
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> acknowledgeShiftLog(num id) async {
    await api.send('PATCH', '/shift-logs/$id/acknowledge');
  }

  // 15. CONTROLE DE CHAVES E TAGS DA PORTARIA
  Future<List<Map<String, dynamic>>> getKeys(
    num condoId, {
    String? status,
  }) async {
    final q = (status != null && status.isNotEmpty) ? '?status=$status' : '';
    final res = await api.get('/condominiums/$condoId/keys$q');
    return _asList(res);
  }

  Future<Map<String, dynamic>> createKey(
    num condoId,
    Map<String, dynamic> body,
  ) async {
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/keys',
      body: body,
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> checkoutKey(num id, Map<String, dynamic> body) async {
    await api.send('POST', '/keys/$id/checkout', body: body);
  }

  Future<void> checkinKey(num id, {String? notes}) async {
    await api.send(
      'POST',
      '/keys/$id/checkin',
      body: {if (notes != null) 'notes': notes},
    );
  }

  // 16. BOTÃO DE PÂNICO & ALERTA DE EMERGÊNCIA (SOS)
  Future<List<Map<String, dynamic>>> getEmergencyAlerts(
    num condoId, {
    String? status,
  }) async {
    final q = (status != null && status.isNotEmpty) ? '?status=$status' : '';
    final res = await api.get('/condominiums/$condoId/emergency-alerts$q');
    return _asList(res);
  }

  Future<Map<String, dynamic>> triggerEmergencyAlert(
    num condoId,
    Map<String, dynamic> body,
  ) async {
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/emergency-alerts',
      body: body,
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> attendEmergencyAlert(num id) async {
    await api.send('PATCH', '/emergency-alerts/$id/attend');
  }

  Future<void> resolveEmergencyAlert(num id, {String? resolutionNotes}) async {
    await api.send(
      'PATCH',
      '/emergency-alerts/$id/resolve',
      body: {if (resolutionNotes != null) 'resolutionNotes': resolutionNotes},
    );
  }

  // 17. MEDIÇÃO INDIVIDUALIZADA DE ÁGUA E GÁS
  Future<List<Map<String, dynamic>>> getUtilityReadings(
    num condoId, {
    int? year,
    int? month,
    num? unitId,
  }) async {
    final params = <String>[];
    if (year != null) params.add('year=$year');
    if (month != null) params.add('month=$month');
    if (unitId != null) params.add('unitId=$unitId');
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    final res = await api.get('/condominiums/$condoId/utility-readings$q');
    return _asList(res);
  }

  Future<Map<String, dynamic>> createUtilityReading(
    num condoId,
    Map<String, dynamic> body,
  ) async {
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/utility-readings',
      body: body,
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  // 18. PREVISÃO ORÇAMENTÁRIA vs REALIZADO
  Future<Map<String, dynamic>> getBudgetComparison(
    num condoId, {
    int? year,
    int? month,
  }) async {
    final params = <String>[];
    if (year != null) params.add('year=$year');
    if (month != null) params.add('month=$month');
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    final res = await api.get(
      '/condominiums/$condoId/financial/budget-comparison$q',
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> saveBudgetForecast(
    num condoId,
    Map<String, dynamic> body,
  ) async {
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/financial/budgets',
      body: body,
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  // 19. CHECKLISTS DE INSPEÇÃO PREDIAL
  Future<List<Map<String, dynamic>>> getChecklists(num condoId) async {
    final res = await api.get('/condominiums/$condoId/maintenance/checklists');
    return _asList(res);
  }

  Future<Map<String, dynamic>> createChecklist(
    num condoId,
    Map<String, dynamic> body,
  ) async {
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/maintenance/checklists',
      body: body,
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> completeChecklist(num id, {String? generalNotes}) async {
    await api.send(
      'PATCH',
      '/maintenance/checklists/$id/complete',
      body: {if (generalNotes != null) 'generalNotes': generalNotes},
    );
  }

  // 20. CONTRATOS E GARANTIAS
  Future<List<Map<String, dynamic>>> getContracts(
    num condoId, {
    String? status,
  }) async {
    final q = (status != null && status.isNotEmpty) ? '?status=$status' : '';
    final res = await api.get('/condominiums/$condoId/contracts$q');
    return _asList(res);
  }

  Future<Map<String, dynamic>> createContract(
    num condoId,
    Map<String, dynamic> body,
  ) async {
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/contracts',
      body: body,
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> terminateContract(num id) async {
    await api.send('PATCH', '/contracts/$id/terminate');
  }

  // 21. CONVITE DIGITAL WHATSAPP
  Future<Map<String, dynamic>> getVisitorDigitalPass(num visitorId) async {
    final res = await api.get('/visitors/$visitorId/digital-pass');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

}
