import 'package:flutter/material.dart';

import '../../home/data/home_service.dart';
import 'admin_schema_editor_dialog.dart';

const List<(String, String, IconData)> kAdminCreatableResources = [
  ('Usuários', 'users', Icons.people_alt_outlined),
  ('Condomínios', 'condominiums', Icons.apartment_outlined),
  ('Vínculos', 'memberships', Icons.admin_panel_settings_outlined),
  ('Setores', 'sectors', Icons.domain_outlined),
  ('Unidades', 'units', Icons.home_work_outlined),
  ('Moradores', 'residents', Icons.groups_outlined),
  ('Encomendas', 'packages', Icons.inventory_2_outlined),
  ('Comunicados', 'announcements', Icons.campaign_outlined),
  ('Áreas comuns', 'common-areas', Icons.deck_outlined),
  ('Planos', 'billing-plans', Icons.receipt_long_outlined),
  ('Despesas', 'expenses', Icons.attach_money_outlined),
];

const Set<String> kAdminEditableResourceKeys = {
  'users',
  'condominiums',
  'condominium-subscriptions',
  'memberships',
  'sectors',
  'units',
  'residents',
  'packages',
  'announcements',
  'common-areas',
  'billing-plans',
  'tickets',
  'expenses',
  'infractions',
};

const Set<String> kAdminDeletableResourceKeys = {
  'users',
  'memberships',
  'sectors',
  'units',
  'residents',
  'packages',
};

bool adminResourceSupportsCreate(String resource) =>
    kAdminCreatableResources.any((entry) => entry.$2 == resource);

Future<Map<String, dynamic>?> showCreateAdminResourceDialog({
  required BuildContext context,
  required HomeService api,
  required String resource,
  required String title,
}) {
  if (!adminResourceSupportsCreate(resource)) return Future.value(null);
  return showSchemaAdminRecordDialog(
    context: context,
    api: api,
    resource: resource,
    title: title,
  );
}

Future<Map<String, dynamic>?> showEditAdminResourceDialog({
  required BuildContext context,
  required HomeService api,
  required String resource,
  required Map<String, dynamic> item,
}) {
  if (!kAdminEditableResourceKeys.contains(resource)) {
    return Future.value(null);
  }
  return showSchemaAdminRecordDialog(
    context: context,
    api: api,
    resource: resource,
    existingItem: item,
  );
}
