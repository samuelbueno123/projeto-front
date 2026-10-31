import 'package:flutter/material.dart';

import '../../home/data/home_service.dart';

/// Access to the units/residents directory of one condominium
/// (`/condominiums/{id}/directory/...`), with in-memory caching.
class DirectoryApi {
  DirectoryApi({required this.api, required this.condominiumId});

  final HomeService api;
  final int condominiumId;

  List<Map<String, dynamic>>? _units;
  final Map<int, List<Map<String, dynamic>>> _residents = {};

  static List<Map<String, dynamic>> _asList(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  Future<List<Map<String, dynamic>>> units({bool refresh = false}) async {
    if (_units == null || refresh) {
      _units = _asList(
        await api.get('/condominiums/$condominiumId/directory/units'),
      );
    }
    return _units!;
  }

  Future<List<Map<String, dynamic>>> residents(
    int unitId, {
    bool refresh = false,
  }) async {
    if (!_residents.containsKey(unitId) || refresh) {
      _residents[unitId] = _asList(
        await api.get(
          '/condominiums/$condominiumId/directory/units/$unitId/residents',
        ),
      );
    }
    return _residents[unitId]!;
  }
}

String sectorTypeLabel(dynamic type) => switch (type) {
  'BLOCK' => 'Bloco',
  'STREET' => 'Rua',
  'COURT' => 'Quadra',
  'GRILL' => 'Área gourmet',
  _ => 'Setor',
};

IconData sectorTypeIcon(dynamic type) => switch (type) {
  'BLOCK' => Icons.domain_outlined,
  'STREET' => Icons.signpost_outlined,
  'COURT' => Icons.grid_view_outlined,
  'GRILL' => Icons.outdoor_grill_outlined,
  _ => Icons.location_city_outlined,
};

String residentTypeLabel(dynamic type) => switch (type) {
  'OWNER' => 'Proprietário',
  'TENANT' => 'Inquilino',
  'DEPENDENT' => 'Dependente',
  _ => 'Morador',
};

/// Human readable unit name, e.g. `Bloco A • Unidade 101`.
String unitLabel(Map<String, dynamic> unit) {
  final sector = (unit['sectorName'] ?? unit['sector'])?.toString() ?? '';
  final identifier = unit['identifier']?.toString() ?? '';
  return sector.isEmpty
      ? 'Unidade $identifier'
      : '$sector • Unidade $identifier';
}

int? _asInt(dynamic value) => value is num ? value.toInt() : null;

/// Result of [showUnitResidentPicker].
class UnitResidentSelection {
  const UnitResidentSelection({required this.unit, this.resident});

  final Map<String, dynamic> unit;

  /// `null` when the unit has no residents / none was chosen.
  final Map<String, dynamic>? resident;
}

/// Opens a bottom sheet where the user searches a unit of the condominium
/// and, after tapping it, sees the names of the residents registered there.
///
/// When [pickResident] is `false` only the unit is chosen (the result has a
/// `null` resident).
Future<UnitResidentSelection?> showUnitResidentPicker(
  BuildContext context, {
  required DirectoryApi directory,
  bool pickResident = true,
  String title = 'Selecionar unidade',
}) => showModalBottomSheet<UnitResidentSelection>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => FractionallySizedBox(
    heightFactor: 0.85,
    child: _UnitResidentPicker(
      directory: directory,
      pickResident: pickResident,
      title: title,
    ),
  ),
);

class _UnitResidentPicker extends StatefulWidget {
  const _UnitResidentPicker({
    required this.directory,
    required this.pickResident,
    required this.title,
  });

  final DirectoryApi directory;
  final bool pickResident;
  final String title;

  @override
  State<_UnitResidentPicker> createState() => _UnitResidentPickerState();
}

class _UnitResidentPickerState extends State<_UnitResidentPicker> {
  final _search = TextEditingController();
  late Future<List<Map<String, dynamic>>> _units = widget.directory.units();
  Map<String, dynamic>? _unit;
  Future<List<Map<String, dynamic>>>? _residents;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _selectUnit(Map<String, dynamic> unit) {
    if (!widget.pickResident) {
      Navigator.pop(context, UnitResidentSelection(unit: unit));
      return;
    }
    final id = _asInt(unit['id']);
    if (id == null) return;
    setState(() {
      _unit = unit;
      _residents = widget.directory.residents(id);
    });
  }

  @override
  Widget build(BuildContext context) =>
      _unit == null ? _unitStep() : _residentStep(_unit!);

  Widget _unitStep() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            widget.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: TextField(
          controller: _search,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Pesquisar bloco, rua ou número da unidade',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(_search.clear),
                  ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _units,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorRetry(
                message: snapshot.error.toString(),
                onRetry: () => setState(
                  () => _units = widget.directory.units(refresh: true),
                ),
              );
            }
            final query = _search.text.trim().toLowerCase();
            final units = (snapshot.data ?? [])
                .where(
                  (u) =>
                      query.isEmpty ||
                      '${u['sectorName']} ${u['identifier']} ${sectorTypeLabel(u['sectorType'])}'
                          .toLowerCase()
                          .contains(query),
                )
                .toList();
            if (units.isEmpty) {
              return const Center(child: Text('Nenhuma unidade encontrada.'));
            }
            return ListView.builder(
              itemCount: units.length,
              itemBuilder: (context, index) {
                final unit = units[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE8ECFF),
                    child: Icon(
                      sectorTypeIcon(unit['sectorType']),
                      color: const Color(0xFF2F3FB0),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Unidade ${unit['identifier']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${sectorTypeLabel(unit['sectorType'])}: ${unit['sectorName']}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _selectUnit(unit),
                );
              },
            );
          },
        ),
      ),
    ],
  );

  Widget _residentStep(Map<String, dynamic> unit) => Column(
    children: [
      ListTile(
        leading: IconButton(
          tooltip: 'Voltar para a lista de unidades',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() {
            _unit = null;
            _residents = null;
          }),
        ),
        title: Text(
          unitLabel(unit),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        subtitle: const Text('Moradores cadastrados nesta unidade'),
      ),
      const Divider(height: 1),
      Expanded(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _residents,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorRetry(
                message: snapshot.error.toString(),
                onRetry: () => setState(
                  () => _residents = widget.directory.residents(
                    _asInt(unit['id'])!,
                    refresh: true,
                  ),
                ),
              );
            }
            final residents = snapshot.data ?? [];
            if (residents.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Nenhum morador registrado nesta unidade.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(
                          context,
                          UnitResidentSelection(unit: unit),
                        ),
                        child: const Text('Continuar sem destinatário'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.builder(
              itemCount: residents.length,
              itemBuilder: (context, index) {
                final resident = residents[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE0E7FF),
                    foregroundColor: const Color(0xFF2F3FB0),
                    child: Text(
                      _initial(resident['name']),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(
                    resident['name']?.toString() ?? 'Morador',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(residentTypeLabel(resident['type'])),
                  onTap: () => Navigator.pop(
                    context,
                    UnitResidentSelection(unit: unit, resident: resident),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

String _initial(dynamic name) {
  final text = name?.toString().trim() ?? '';
  return text.isEmpty ? '?' : text[0].toUpperCase();
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}

/// Quick hierarchical list: sector (block/street/court...) → unit → residents.
/// Each resident has a "+" button to start a package registration, and each
/// unit has a button to send an announcement to that unit.
class UnitDirectoryView extends StatefulWidget {
  const UnitDirectoryView({
    super.key,
    required this.directory,
    required this.onRegisterPackage,
    this.onAnnounce,
  });

  final DirectoryApi directory;

  /// Called with the unit and the chosen resident.
  final void Function(Map<String, dynamic> unit, Map<String, dynamic> resident)
  onRegisterPackage;

  /// Called with the chosen unit. The announce button is hidden when null.
  final void Function(Map<String, dynamic> unit)? onAnnounce;

  @override
  State<UnitDirectoryView> createState() => _UnitDirectoryViewState();
}

class _UnitDirectoryViewState extends State<UnitDirectoryView> {
  final _search = TextEditingController();
  late Future<List<Map<String, dynamic>>> _units = widget.directory.units();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant UnitDirectoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.directory != widget.directory) {
      _units = widget.directory.units();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
        child: TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Pesquisar bloco, rua ou unidade',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(_search.clear),
                  ),
          ),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _units,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorRetry(
                message: snapshot.error.toString(),
                onRetry: () => setState(
                  () => _units = widget.directory.units(refresh: true),
                ),
              );
            }
            final query = _search.text.trim().toLowerCase();
            final grouped = <String, List<Map<String, dynamic>>>{};
            final sectorTypes = <String, dynamic>{};
            for (final unit in snapshot.data ?? <Map<String, dynamic>>[]) {
              final sector = unit['sectorName']?.toString() ?? 'Sem setor';
              final matches =
                  query.isEmpty ||
                  '$sector ${unit['identifier']}'.toLowerCase().contains(query);
              if (!matches) continue;
              grouped.putIfAbsent(sector, () => []).add(unit);
              sectorTypes[sector] = unit['sectorType'];
            }
            if (grouped.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nenhuma unidade encontrada neste condomínio.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                setState(() => _units = widget.directory.units(refresh: true));
                await _units;
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 96),
                children: [
                  for (final entry in grouped.entries)
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        key: PageStorageKey('sector-${entry.key}'),
                        initiallyExpanded: query.isNotEmpty,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE8ECFF),
                          child: Icon(
                            sectorTypeIcon(sectorTypes[entry.key]),
                            color: const Color(0xFF2F3FB0),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${sectorTypeLabel(sectorTypes[entry.key])} • ${entry.value.length} unidade(s)',
                        ),
                        children: [
                          for (final unit in entry.value)
                            _UnitTile(
                              unit: unit,
                              directory: widget.directory,
                              onRegisterPackage: widget.onRegisterPackage,
                              onAnnounce: widget.onAnnounce,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _UnitTile extends StatelessWidget {
  const _UnitTile({
    required this.unit,
    required this.directory,
    required this.onRegisterPackage,
    this.onAnnounce,
  });

  final Map<String, dynamic> unit;
  final DirectoryApi directory;
  final void Function(Map<String, dynamic> unit, Map<String, dynamic> resident)
  onRegisterPackage;
  final void Function(Map<String, dynamic> unit)? onAnnounce;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: PageStorageKey('unit-${unit['id']}'),
    tilePadding: const EdgeInsets.only(left: 28, right: 8),
    leading: const Icon(Icons.home_outlined, color: Color(0xFF475569)),
    title: Text(
      'Unidade ${unit['identifier']}',
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    subtitle: const Text('Toque para ver os moradores'),
    children: [
      FutureBuilder<List<Map<String, dynamic>>>(
        future: directory.residents(_asInt(unit['id']) ?? 0),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(snapshot.error.toString()),
            );
          }
          final residents = snapshot.data ?? [];
          return Column(
            children: [
              if (residents.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nenhum morador registrado nesta unidade.'),
                ),
              for (final resident in residents)
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 44, right: 8),
                  leading: CircleAvatar(
                    radius: 17,
                    backgroundColor: const Color(0xFFE0E7FF),
                    foregroundColor: const Color(0xFF2F3FB0),
                    child: Text(_initial(resident['name'])),
                  ),
                  title: Text(resident['name']?.toString() ?? 'Morador'),
                  subtitle: Text(residentTypeLabel(resident['type'])),
                  trailing: IconButton.filledTonal(
                    tooltip: 'Registrar encomenda para este morador',
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () => onRegisterPackage(unit, resident),
                  ),
                ),
              if (onAnnounce != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12, bottom: 8),
                    child: TextButton.icon(
                      onPressed: () => onAnnounce!(unit),
                      icon: const Icon(Icons.campaign_outlined, size: 18),
                      label: const Text('Enviar comunicado à unidade'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}
