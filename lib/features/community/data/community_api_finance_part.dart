part of 'community_api.dart';

extension CommunityApiFinanceExtension on CommunityApi {
  // 16. BOLETOS E COBRANÇAS CONDOMINIAIS
  Future<List<Map<String, dynamic>>> getMyInvoices(num condoId) async {
    final res = await api.get('/condominiums/$condoId/my-invoices');
    return _asList(res);
  }

  Future<Map<String, dynamic>> getUnitPaymentStatus(
    num condoId,
    num unitId,
  ) async {
    final res = await api.get(
      '/condominiums/$condoId/units/$unitId/payment-status',
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> generateBoleto(
    num condoId,
    num unitId, {
    required double amount,
    required DateTime dueDate,
    required String title,
  }) async {
    final dateStr =
        '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
    final res = await api.send(
      'POST',
      '/manager/condominiums/$condoId/units/$unitId/generate-boleto',
      body: {'amount': amount, 'dueDate': dateStr, 'title': title},
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> payBoleto(num condoId, num unitId) async {
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/units/$unitId/pay-boleto',
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  // 17. ONBOARDING DE PLANOS, ASSINATURAS & BOAS-VINDAS
  Future<List<Map<String, dynamic>>> getBillingPlans() async {
    final res = await api.get('/billing/plans');
    return _asList(res);
  }

  Future<Map<String, dynamic>?> getCondominiumSubscription(num condoId) async {
    final res = await api.get('/condominiums/$condoId/subscription');
    return res is Map<String, dynamic> ? res : null;
  }

  Future<List<Map<String, dynamic>>> getSubscriptionHistory(num condoId) async {
    final res = await api.get('/condominiums/$condoId/subscription/history');
    return _asList(res);
  }

  Future<Map<String, dynamic>> changeSubscriptionPlan(
    num condoId, {
    required num planId,
    String? billingCycle,
    String? reason,
  }) async {
    final res = await api.send(
      'PUT',
      '/manager/condominiums/$condoId/subscription/plan',
      body: {
        'planId': planId,
        if (billingCycle != null) 'billingCycle': billingCycle,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getAdminSubscriptions() async {
    final res = await api.get('/admin/subscriptions');
    return _asList(res);
  }

  Future<Map<String, dynamic>> updateAdminSubscriptionPlan(
    num condoId, {
    required num planId,
    String? billingCycle,
    String? reason,
  }) async {
    final res = await api.send(
      'PUT',
      '/admin/subscriptions/$condoId/plan',
      body: {
        'planId': planId,
        if (billingCycle != null) 'billingCycle': billingCycle,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateAdminSubscriptionStatus(
    num condoId, {
    required String status,
    String? reason,
  }) async {
    final res = await api.send(
      'PATCH',
      '/admin/subscriptions/$condoId/status',
      body: {
        'status': status,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> renewAdminSubscription(
    num condoId, {
    int months = 1,
    String? reason,
  }) async {
    final res = await api.send(
      'POST',
      '/admin/subscriptions/$condoId/renew',
      body: {
        'months': months,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> selectCondominiumPlan(
    num condoId,
    num planId,
  ) async {
    final res = await api.send(
      'PUT',
      '/manager/condominiums/$condoId/select-plan',
      body: {'planId': planId},
    );
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
    final dateStr =
        '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/financial/expenses',
      body: {
        'category': category,
        'description': description,
        'amount': amount,
        'dueDate': dateStr,
        if (supplier != null && supplier.isNotEmpty) 'supplier': supplier,
        if (documentNumber != null && documentNumber.isNotEmpty)
          'documentNumber': documentNumber,
        if (receiptUrl != null && receiptUrl.isNotEmpty)
          'receiptUrl': receiptUrl,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> payExpense(num expenseId) async {
    final res = await api.send('PATCH', '/financial/expenses/$expenseId/pay');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> cancelExpense(num expenseId) async {
    final res = await api.send(
      'PATCH',
      '/financial/expenses/$expenseId/cancel',
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  // 20. MANUTENÇÃO PREDIAL E ORDENS DE SERVIÇO
  Future<List<Map<String, dynamic>>> listMaintenanceOrders(
    num condoId, [
    String? status,
  ]) async {
    final query = status != null && status.isNotEmpty ? '?status=$status' : '';
    final res = await api.get(
      '/condominiums/$condoId/maintenance/orders$query',
    );
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
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/maintenance/orders',
      body: {
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
      },
    );
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
    final res = await api.send(
      'PATCH',
      '/maintenance/orders/$id/status',
      body: {
        'status': status,
        if (actualCost != null) 'actualCost': actualCost,
        if (notes != null) 'notes': notes,
        if (supplierRating != null) 'supplierRating': supplierRating,
        if (supplierFeedback != null && supplierFeedback.isNotEmpty)
          'supplierFeedback': supplierFeedback,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listMaintenanceEquipment(
    num condoId,
  ) async {
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
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/maintenance/equipment',
      body: {
        'name': name,
        'category': category,
        if (location != null && location.isNotEmpty) 'location': location,
        if (manufacturer != null && manufacturer.isNotEmpty)
          'manufacturer': manufacturer,
        'recurrenceDays': recurrenceDays,
        if (nextMaintenanceDate != null && nextMaintenanceDate.isNotEmpty)
          'nextMaintenanceDate': nextMaintenanceDate,
        if (responsibleName != null && responsibleName.isNotEmpty)
          'responsibleName': responsibleName,
        if (preferredSupplierId != null)
          'preferredSupplierId': preferredSupplierId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
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
    final res = await api.send(
      'POST',
      '/condominiums/$condoId/suppliers',
      body: {
        'companyName': companyName,
        'serviceCategory': serviceCategory,
        if (contactName != null && contactName.isNotEmpty)
          'contactName': contactName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        if (documentNumber != null && documentNumber.isNotEmpty)
          'documentNumber': documentNumber,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<void> deleteSupplier(num id) async {
    await api.send('DELETE', '/suppliers/$id');
  }

}
