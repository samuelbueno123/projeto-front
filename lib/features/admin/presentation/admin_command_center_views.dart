import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/saas_design_system.dart';
import '../../home/data/home_service.dart';

// ============================================================================
// 1. AUDIT LOG VIEW (Logs e Auditoria Imutáveis)
// ============================================================================
class AdminAuditLogView extends StatefulWidget {
  const AdminAuditLogView({
    super.key,
    required this.api,
    this.condominiumId,
  });

  final HomeService api;
  final int? condominiumId;

  @override
  State<AdminAuditLogView> createState() => _AdminAuditLogViewState();
}

class _AdminAuditLogViewState extends State<AdminAuditLogView> {
  bool _loading = false;
  String? _error;
  List<dynamic> _items = [];
  Map<String, dynamic> _stats = {};
  int _page = 0;
  int _totalPages = 1;
  int _totalElements = 0;

  String _category = 'ALL';
  String _severity = 'ALL';
  String _outcome = 'ALL';
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _searchCtrl = TextEditingController();

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
  final DateFormat _dayFormat = DateFormat('dd/MM/yyyy');

  static const List<String> _categories = [
    'ALL',
    'SECURITY',
    'AUTHENTICATION',
    'ADMIN_OPERATION',
    'SYSTEM',
    'ACCESS_CONTROL',
  ];

  static const List<String> _severities = [
    'ALL',
    'INFO',
    'WARN',
    'ERROR',
    'CRITICAL',
  ];

  static const List<String> _outcomes = [
    'ALL',
    'SUCCESS',
    'FAILURE',
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadLogs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final res = await widget.api.get('/admin/audit-logs/stats');
      if (mounted && res is Map<String, dynamic>) {
        setState(() => _stats = res);
      }
    } catch (_) {}
  }

  Future<void> _loadLogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final queryParams = <String, String>{
        'page': '$_page',
        'size': '20',
        'sort': 'timestamp,desc',
      };

      if (_category != 'ALL') queryParams['category'] = _category;
      if (_severity != 'ALL') queryParams['severity'] = _severity;
      if (_outcome != 'ALL') queryParams['outcome'] = _outcome;
      if (_startDate != null) {
        queryParams['startDate'] = _startDate!.toIso8601String().substring(0, 10);
      }
      if (_endDate != null) {
        queryParams['endDate'] = _endDate!.toIso8601String().substring(0, 10);
      }
      if (_searchCtrl.text.trim().isNotEmpty) {
        queryParams['query'] = _searchCtrl.text.trim();
      }
      if (widget.condominiumId != null) {
        queryParams['condominiumId'] = '${widget.condominiumId}';
      }

      final uri = Uri(
        path: '/admin/audit-logs',
        queryParameters: queryParams,
      );

      final res = await widget.api.get(uri.toString());

      if (mounted) {
        if (res is Map<String, dynamic>) {
          setState(() {
            _items = (res['content'] as List<dynamic>?) ?? [];
            _totalPages = (res['totalPages'] as num?)?.toInt() ?? 1;
            _totalElements = (res['totalElements'] as num?)?.toInt() ?? _items.length;
            _loading = false;
          });
        } else if (res is List<dynamic>) {
          setState(() {
            _items = res;
            _totalPages = 1;
            _totalElements = res.length;
            _loading = false;
          });
        } else {
          setState(() {
            _items = [];
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar logs de auditoria: $e';
          _loading = false;
        });
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _category = 'ALL';
      _severity = 'ALL';
      _outcome = 'ALL';
      _startDate = null;
      _endDate = null;
      _searchCtrl.clear();
      _page = 0;
    });
    _loadLogs();
  }

  void _showAuditDetailDialog(Map<String, dynamic> item) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final timestampStr = item['timestamp']?.toString() ?? '';
        DateTime? dt;
        try {
          dt = DateTime.parse(timestampStr).toLocal();
        } catch (_) {}

        final severity = item['severity']?.toString() ?? 'INFO';
        final outcome = item['outcome']?.toString() ?? 'SUCCESS';
        final isSuccess = outcome.toUpperCase() == 'SUCCESS';

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSuccess
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFFEF4444).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuccess ? Icons.verified_user_outlined : Icons.warning_amber_rounded,
                  color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registro de Auditoria #${item['id'] ?? ''}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      dt != null ? _dateFormat.format(dt) : timestampStr,
                      style: TextStyle(fontSize: 12, color: SaaSColors.muted(ctx)),
                    ),
                  ],
                ),
              ),
              _buildSeverityBadge(severity),
            ],
          ),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Ação / Operação', item['action']?.toString() ?? '-'),
                  _buildDetailRow('Tipo de Evento', item['eventType']?.toString() ?? '-'),
                  _buildDetailRow('Categoria', item['category']?.toString() ?? '-'),
                  _buildDetailRow('Usuário (Principal)', item['principal']?.toString() ?? 'SYSTEM'),
                  _buildDetailRow('Desfecho', outcome, isSuccess: isSuccess),
                  _buildDetailRow('Endereço IP', item['ipAddress']?.toString() ?? '127.0.0.1'),
                  if (item['condominiumId'] != null)
                    _buildDetailRow(
                      'Condomínio',
                      '#${item['condominiumId']} ${item['condominiumName'] ?? ''}',
                    ),
                  if (item['resourceType'] != null)
                    _buildDetailRow(
                      'Recurso Afetado',
                      '${item['resourceType']} (ID: ${item['resourceId'] ?? '-'})',
                    ),
                  if (item['correlationId'] != null)
                    _buildDetailRow(
                      'Correlation ID',
                      item['correlationId'].toString(),
                      canCopy: true,
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Detalhes Adicionais:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: SelectableText(
                      item['details']?.toString() ?? 'Nenhum detalhe adicional fornecido.',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool? isSuccess, bool canCopy = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: SaaSColors.muted(context),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSuccess == null
                          ? null
                          : (isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                    ),
                  ),
                ),
                if (canCopy)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 14),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Copiar',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Correlation ID copiado!')),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityBadge(String severity) {
    Color bg;
    Color fg;
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        bg = const Color(0xFF7C3AED).withValues(alpha: 0.15);
        fg = const Color(0xFF7C3AED);
        break;
      case 'ERROR':
        bg = const Color(0xFFEF4444).withValues(alpha: 0.15);
        fg = const Color(0xFFEF4444);
        break;
      case 'WARN':
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        fg = const Color(0xFFD97706);
        break;
      case 'INFO':
      default:
        bg = const Color(0xFF2563EB).withValues(alpha: 0.15);
        fg = const Color(0xFF2563EB);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        severity.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Immutability Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF4F46E5), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                      ),
                      children: const [
                        TextSpan(
                          text: '🔒 Trilha de Auditoria Imutável: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              'Todos os registros são gravados em transação isolada e permanente (WORM). Edições e exclusões são bloqueadas por integridade e conformidade de segurança.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stats Cards
          Row(
            children: [
              Expanded(
                child: SaaSMetricCard(
                  title: 'Total de Registros',
                  value: '${_stats['total'] ?? _totalElements}',
                  icon: Icons.history_edu_outlined,
                  subtitle: 'eventos auditados',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SaaSMetricCard(
                  title: 'Falhas / Bloqueios',
                  value: '${(_stats['byOutcome'] as Map?)?['FAILURE'] ?? 0}',
                  icon: Icons.gpp_bad_outlined,
                  subtitle: 'acesso negado ou erro',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SaaSMetricCard(
                  title: 'Operações Admin',
                  value: '${(_stats['byCategory'] as Map?)?['ADMIN_OPERATION'] ?? 0}',
                  icon: Icons.manage_accounts_outlined,
                  subtitle: 'ações de governança',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SaaSMetricCard(
                  title: 'Alertas Críticos / Erro',
                  value:
                      '${((_stats['bySeverity'] as Map?)?['ERROR'] ?? 0) + ((_stats['bySeverity'] as Map?)?['CRITICAL'] ?? 0)}',
                  icon: Icons.notification_important_outlined,
                  subtitle: 'requer atenção',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filters Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.filter_list, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Filtros de Auditoria',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.clear_all, size: 16),
                      label: const Text('Limpar Filtros'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() => _page = 0);
                        _loadLogs();
                      },
                      icon: const Icon(Icons.search, size: 16),
                      label: const Text('Filtrar'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Categoria
                    SizedBox(
                      width: 175,
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        items: _categories
                            .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _category = v);
                        },
                      ),
                    ),
                    // Severidade
                    SizedBox(
                      width: 155,
                      child: DropdownButtonFormField<String>(
                        value: _severity,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Severidade',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        items: _severities
                            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _severity = v);
                        },
                      ),
                    ),
                    // Desfecho
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<String>(
                        value: _outcome,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Desfecho',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        items: _outcomes
                            .map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _outcome = v);
                        },
                      ),
                    ),
                    // Data Início
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (picked != null) setState(() => _startDate = picked);
                      },
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text(
                        _startDate == null ? 'Data Início' : _dayFormat.format(_startDate!),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    // Data Fim
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (picked != null) setState(() => _endDate = picked);
                      },
                      icon: const Icon(Icons.event, size: 16),
                      label: Text(
                        _endDate == null ? 'Data Fim' : _dayFormat.format(_endDate!),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    // Busca Livre
                    SizedBox(
                      width: 250,
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Busca (ação, usuário, IP, ID...)',
                          prefixIcon: const Icon(Icons.search, size: 16),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () => setState(() => _searchCtrl.clear()),
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: (_) {
                          setState(() => _page = 0);
                          _loadLogs();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Audit Table / Cards
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: SaaSLoadingState(message: 'Carregando registros imutáveis de auditoria...'),
              ),
            )
          else if (_error != null)
            SaaSErrorState(message: _error!, onRetry: _loadLogs)
          else if (_items.isEmpty)
            const SaaSEmptyState(
              icon: Icons.shield_outlined,
              title: 'Nenhum registro de auditoria encontrado',
              subtitle: 'Ajuste os filtros ou o período para visualizar mais eventos.',
            )
          else ...[
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      ),
                      columns: const [
                        DataColumn(label: Text('Data / Hora', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Severidade', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Categoria', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Usuário / Principal', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Ação / Evento', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Desfecho', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('IP / Recurso', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _items.map((log) {
                        final item = log is Map<String, dynamic> ? log : <String, dynamic>{};
                        final timestampStr = item['timestamp']?.toString() ?? '';
                        DateTime? dt;
                        try {
                          dt = DateTime.parse(timestampStr).toLocal();
                        } catch (_) {}

                        final severity = item['severity']?.toString() ?? 'INFO';
                        final outcome = item['outcome']?.toString() ?? 'SUCCESS';
                        final isSuccess = outcome.toUpperCase() == 'SUCCESS';

                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                dt != null ? _dateFormat.format(dt) : timestampStr,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DataCell(_buildSeverityBadge(severity)),
                            DataCell(
                              Text(
                                item['category']?.toString() ?? '-',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                            DataCell(
                              Text(
                                item['principal']?.toString() ?? 'SYSTEM',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 220),
                                child: Text(
                                  item['action']?.toString() ?? item['eventType']?.toString() ?? '-',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSuccess ? Icons.check_circle_outline : Icons.cancel_outlined,
                                    size: 16,
                                    color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    outcome,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                item['ipAddress']?.toString() ?? item['resourceType']?.toString() ?? '-',
                                style: TextStyle(fontSize: 11, color: SaaSColors.muted(context)),
                              ),
                            ),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined, size: 18),
                                tooltip: 'Ver detalhes',
                                onPressed: () => _showAuditDetailDialog(item),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                  // Pagination footer
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Text(
                          'Página ${_page + 1} de $_totalPages ($_totalElements registros)',
                          style: TextStyle(fontSize: 12, color: SaaSColors.muted(context)),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.first_page),
                          onPressed: _page > 0
                              ? () {
                                  setState(() => _page = 0);
                                  _loadLogs();
                                }
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _page > 0
                              ? () {
                                  setState(() => _page--);
                                  _loadLogs();
                                }
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _page < _totalPages - 1
                              ? () {
                                  setState(() => _page++);
                                  _loadLogs();
                                }
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.last_page),
                          onPressed: _page < _totalPages - 1
                              ? () {
                                  setState(() => _page = _totalPages - 1);
                                  _loadLogs();
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// 2. DIAGNOSTICS & SYSTEM HEALTH VIEW (Saúde, Métricas e Diagnóstico)
// ============================================================================
class AdminDiagnosticsView extends StatefulWidget {
  const AdminDiagnosticsView({
    super.key,
    required this.api,
  });

  final HomeService api;

  @override
  State<AdminDiagnosticsView> createState() => _AdminDiagnosticsViewState();
}

class _AdminDiagnosticsViewState extends State<AdminDiagnosticsView> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _data;
  bool _autoRefresh = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
    _startTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    if (_autoRefresh && !isRunningTestEnvironment) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted && _autoRefresh) {
          _loadDiagnostics(silent: true);
        }
      });
    }
  }

  Future<void> _loadDiagnostics({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final res = await widget.api.get('/admin/diagnostics');
      if (mounted && res is Map<String, dynamic>) {
        setState(() {
          _data = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (!silent) _error = 'Erro ao consultar diagnósticos: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _evictCaches({String? cacheName}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(cacheName == null ? 'Limpar Todos os Caches?' : 'Limpar Cache $cacheName?'),
        content: Text(
          cacheName == null
              ? 'Esta ação forçará o Spring Cache a invalidar todas as entradas em memória (roles, features, usuários). Uma entrada será registrada na trilha de auditoria.'
              : 'Deseja invalidar o cache "$cacheName"? Uma entrada será registrada na trilha de auditoria.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final url = cacheName != null
          ? '/admin/diagnostics/cache/evict?cacheName=${Uri.encodeQueryComponent(cacheName)}'
          : '/admin/diagnostics/cache/evict';
      final res = await widget.api.post(url, {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Caches limpos com sucesso! (${res is Map ? res['clearedCaches'] : 'OK'})',
            ),
          ),
        );
        _loadDiagnostics();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao limpar cache: $e')),
        );
      }
    }
  }

  void _exportDiagnosticsReport() {
    if (_data == null) return;
    final jsonStr = const JsonEncoder.withIndent('  ').convert(_data);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.terminal, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Relatório de Diagnóstico do Sistema'),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              jsonStr,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copiar JSON'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Diagnóstico copiado para a área de transferência!')),
              );
            },
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    if (_loading && _data == null) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: SaaSLoadingState(message: 'Consultando telemetria e integridade dos serviços...'),
        ),
      );
    }

    if (_error != null && _data == null) {
      return SaaSErrorState(message: _error!, onRetry: () => _loadDiagnostics());
    }

    final data = _data ?? {};
    final overallStatus = data['overallStatus']?.toString() ?? 'UP';
    final isOverallUp = overallStatus.toUpperCase() == 'UP';

    final db = (data['database'] as Map?) ?? {};
    final jvm = (data['jvm'] as Map?) ?? {};
    final disk = (data['disk'] as Map?) ?? {};
    final realtime = (data['realtime'] as Map?) ?? {};
    final caches = (data['caches'] as List?) ?? [];
    final metrics = (data['operationalMetrics'] as Map?) ?? {};

    final heapPercent = ((jvm['heapUsagePercent'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 100.0);
    final diskPercent = ((disk['usagePercent'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 100.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Action Strip
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isOverallUp
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOverallUp ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOverallUp ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isOverallUp ? 'SISTEMA OPERACIONAL (STATUS UP)' : 'STATUS DEGRADADO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isOverallUp ? const Color(0xFF047857) : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Auto-refresh (15s):', style: TextStyle(fontSize: 12)),
                  Switch(
                    value: _autoRefresh,
                    onChanged: (val) {
                      setState(() => _autoRefresh = val);
                      _startTimer();
                    },
                  ),
                ],
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Atualizar'),
                onPressed: () => _loadDiagnostics(),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Exportar Relatório'),
                onPressed: _exportDiagnosticsReport,
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                icon: const Icon(Icons.cleaning_services_outlined, size: 16),
                label: const Text('Limpar Caches'),
                onPressed: () => _evictCaches(),
              ),
            ],
          ),
        ),
          const SizedBox(height: 16),

          // 4 Status Cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Database
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.dns_outlined, color: Color(0xFF2563EB), size: 18),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Banco de Dados',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          _buildStatusPill(db['status']?.toString() ?? 'UP'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${db['latencyMs'] ?? 0} ms',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Latência do ping (${db['validationQuery'] ?? 'SELECT 1'})',
                        style: TextStyle(fontSize: 11, color: SaaSColors.muted(context)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 2. JVM Memory
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.memory_outlined, color: Color(0xFF7C3AED), size: 18),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Memória JVM Heap',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('$heapPercent%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: heapPercent / 100.0,
                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        color: heapPercent > 85 ? const Color(0xFFEF4444) : const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${jvm['heapUsedMb'] ?? 0} MB usados / ${jvm['heapMaxMb'] ?? 0} MB max',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Non-Heap: ${jvm['nonHeapUsedMb'] ?? 0} MB • Uptime: ${(jvm['uptimeSeconds'] ?? 0) ~/ 3600}h ${((jvm['uptimeSeconds'] ?? 0) % 3600) ~/ 60}m',
                        style: TextStyle(fontSize: 11, color: SaaSColors.muted(context)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 3. Disk Space
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.storage_outlined, color: Color(0xFF059669), size: 18),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Armazenamento',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('$diskPercent%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: diskPercent / 100.0,
                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        color: diskPercent > 90 ? const Color(0xFFEF4444) : const Color(0xFF059669),
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${disk['freeMb'] ?? 0} MB livres',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Capacidade total: ${disk['totalMb'] ?? 0} MB',
                        style: TextStyle(fontSize: 11, color: SaaSColors.muted(context)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 4. Realtime SSE
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.stream, color: Color(0xFFD97706), size: 18),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'SSE Realtime',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          _buildStatusPill(realtime['status']?.toString() ?? 'UP'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${realtime['activeConnections'] ?? 0}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${realtime['connectedUsers'] ?? 0} usuários • ${realtime['connectedCondominiums'] ?? 0} condomínios',
                        style: TextStyle(fontSize: 11, color: SaaSColors.muted(context)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Operational Metrics Grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.speed, size: 20, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Text(
                      'Métricas Operacionais em Tempo Real',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildMetricStat('Logins Sucesso', '${metrics['loginSuccess'] ?? 0}', Icons.check_circle_outline, Colors.green),
                    _buildMetricStat('Logins Falha', '${metrics['loginFailure'] ?? 0}', Icons.highlight_off, Colors.red),
                    _buildMetricStat('Reservas Feitas', '${metrics['reservationCreated'] ?? 0}', Icons.event_available, Colors.blue),
                    _buildMetricStat('Conflitos de Reserva', '${metrics['reservationConflict'] ?? 0}', Icons.event_busy, Colors.orange),
                    _buildMetricStat('Encomendas Recebidas', '${metrics['packageReceived'] ?? 0}', Icons.move_to_inbox, Colors.indigo),
                    _buildMetricStat('Alertas de Pânico', '${metrics['emergencyTriggered'] ?? 0}', Icons.emergency_outlined, Colors.redAccent),
                    _buildMetricStat('Check-ins Visitantes', '${metrics['visitorCheckIn'] ?? 0}', Icons.badge_outlined, Colors.teal),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Spring Caches Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cached, size: 20, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 8),
                    const Text(
                      'Caches do Spring Framework (In-Memory Acceleration)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const Spacer(),
                    Text(
                      '${caches.length} caches registrados',
                      style: TextStyle(fontSize: 12, color: SaaSColors.muted(context)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (caches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Nenhum cache ativo no momento.', style: TextStyle(color: SaaSColors.muted(context))),
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: caches.map((c) {
                      final cacheMap = c is Map ? c : {};
                      final name = cacheMap['name']?.toString() ?? 'cache';
                      final count = cacheMap['entries'] ?? 0;
                      return Container(
                        width: 220,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    '$count entradas em cache',
                                    style: TextStyle(fontSize: 11, color: SaaSColors.muted(context)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                              tooltip: 'Limpar este cache',
                              onPressed: () => _evictCaches(cacheName: name),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    final isUp = status.toUpperCase() == 'UP';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isUp ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFEF4444).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
      ),
    );
  }

  Widget _buildMetricStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: SaaSColors.muted(context)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. PERMISSIONS & ROLES MATRIX VIEW (Permissões, Papéis e Planos Comerciais)
// ============================================================================
class AdminPermissionsView extends StatefulWidget {
  const AdminPermissionsView({
    super.key,
    required this.api,
  });

  final HomeService api;

  @override
  State<AdminPermissionsView> createState() => _AdminPermissionsViewState();
}

class _AdminPermissionsViewState extends State<AdminPermissionsView> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _overview;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final matrixFuture = widget.api.get('/admin/permissions-matrix');
      final overviewFuture = widget.api.get('/admin/overview');

      final results = await Future.wait([matrixFuture, overviewFuture]);

      if (mounted) {
        setState(() {
          if (results[0] is Map<String, dynamic>) {
            _data = results[0] as Map<String, dynamic>;
          }
          if (results[1] is Map<String, dynamic>) {
            _overview = results[1] as Map<String, dynamic>;
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar matriz de permissões: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    if (_loading && _data == null) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: SaaSLoadingState(message: 'Carregando matriz de papéis e planos comerciais...'),
        ),
      );
    }

    if (_error != null && _data == null) {
      return SaaSErrorState(message: _error!, onRetry: _loadData);
    }

    final roles = (_data?['roles'] as List?) ?? [];
    final plans = (_data?['commercialPlans'] as List?) ?? [];
    final usersByRole = (_overview?['usersByRole'] as Map?) ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Title: RBAC
          const Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text(
                'Matriz de Controle de Acesso Baseado em Papéis (RBAC)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Hierarquia de segurança com controle granular em todas as camadas da aplicação (REST API, métodos com @PreAuthorize e rotas da interface).',
            style: TextStyle(fontSize: 13, color: SaaSColors.muted(context)),
          ),
          const SizedBox(height: 16),

          // 4 Roles Grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: roles.map((r) {
              final roleMap = r is Map ? r : {};
              final roleName = roleMap['role']?.toString() ?? '';
              final label = roleMap['label']?.toString() ?? roleName;
              final scope = roleMap['scope']?.toString() ?? '';
              final permissions = (roleMap['permissions'] as List?) ?? [];
              final userCount = usersByRole[roleName] ?? 0;

              Color accentColor;
              IconData roleIcon;
              switch (roleName) {
                case 'ROLE_ADMIN':
                  accentColor = const Color(0xFFEF4444);
                  roleIcon = Icons.shield;
                  break;
                case 'ROLE_MANAGER':
                  accentColor = const Color(0xFF2563EB);
                  roleIcon = Icons.domain;
                  break;
                case 'ROLE_DOORMAN':
                  accentColor = const Color(0xFFD97706);
                  roleIcon = Icons.security;
                  break;
                case 'ROLE_RESIDENT':
                default:
                  accentColor = const Color(0xFF059669);
                  roleIcon = Icons.home;
                  break;
              }

              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: accentColor.withValues(alpha: 0.15),
                            radius: 18,
                            child: Icon(roleIcon, color: accentColor, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  roleName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: accentColor,
                                  ),
                                ),
                                Text(
                                  '$userCount usuários',
                                  style: TextStyle(fontSize: 11, color: SaaSColors.muted(context)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Escopo: $scope',
                          style: TextStyle(fontSize: 10.5, color: SaaSColors.muted(context)),
                        ),
                      ),
                      const Divider(height: 20),
                      ...permissions.map(
                        (p) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check, size: 14, color: Color(0xFF10B981)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  p.toString(),
                                  style: const TextStyle(fontSize: 11.5, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // Section Title: Commercial Plans
          const Row(
            children: [
              Icon(Icons.workspace_premium_outlined, color: Color(0xFF7C3AED)),
              SizedBox(width: 8),
              Text(
                'Planos Comerciais e Catálogo de Recursos de Assinatura',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Recursos ativados por condomínio de acordo com o plano contratado (CondominiumFeatureAccessService).',
            style: TextStyle(fontSize: 13, color: SaaSColors.muted(context)),
          ),
          const SizedBox(height: 16),

          // Commercial Plans Cards
          if (plans.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Nenhum plano cadastrado.', style: TextStyle(color: SaaSColors.muted(context))),
            )
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: plans.map((p) {
                final planMap = p is Map ? p : {};
                final planName = planMap['name']?.toString() ?? 'Plano';
                final monthlyFee = planMap['monthlyFee'];
                final feeStr = monthlyFee != null ? 'R\$ $monthlyFee/mês' : 'Sob consulta';
                final features = (planMap['features'] as List?) ?? [];

                return Container(
                  width: 320,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              planName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'ATIVO',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        feeStr,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                      const Divider(height: 20),
                      Text(
                        'Recursos Incluídos (${features.length}):',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      ...features.map((f) {
                        final fMap = f is Map ? f : {};
                        final fName = fMap['name']?.toString() ?? fMap['code']?.toString() ?? f.toString();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF10B981)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(fName, style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
