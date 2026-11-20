import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Retorna o primeiro nome não vazio de um nome completo.
String firstNameOf(String? fullName, {String fallback = ''}) {
  if (fullName == null) return fallback;
  final trimmed = fullName.trim();
  if (trimmed.isEmpty) return fallback;
  final parts = trimmed.split(RegExp(r'\s+'));
  return parts.first.isEmpty ? fallback : parts.first;
}

String onlyDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

/// Formata um telefone brasileiro (10 ou 11 dígitos) preservando strings vazias.
String formatPhone(String? value) {
  if (value == null) return '';
  final digits = onlyDigits(value);
  if (digits.isEmpty) return '';
  final capped = digits.length > 11 ? digits.substring(0, 11) : digits;
  if (capped.length <= 2) return '($capped';
  if (capped.length <= 6) {
    return '(${capped.substring(0, 2)}) ${capped.substring(2)}';
  }
  if (capped.length <= 10) {
    return '(${capped.substring(0, 2)}) ${capped.substring(2, 6)}-${capped.substring(6)}';
  }
  return '(${capped.substring(0, 2)}) ${capped.substring(2, 7)}-${capped.substring(7)}';
}

/// Valida telefone brasileiro (10 dígitos fixo ou 11 dígitos celular com DDD).
String? validatePhone(String? value, {bool required = false}) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) {
    return required ? 'Informe o telefone com DDD.' : null;
  }
  final digits = onlyDigits(raw);
  if (digits.length < 10 || digits.length > 11) {
    return 'Informe um telefone válido com DDD (10 ou 11 dígitos).';
  }
  if (digits[0] == '0' || digits[1] == '0') {
    return 'DDD inválido. Informe um DDD válido com 2 dígitos.';
  }
  return null;
}

/// Formata telefone brasileiro em tempo real preservando a posição do cursor.
class PhoneInputFormatter extends TextInputFormatter {
  const PhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final selectionEnd = newValue.selection.end.clamp(0, newValue.text.length);
    final digitsBeforeCursor = onlyDigits(
      newValue.text.substring(0, selectionEnd),
    ).length;

    final allDigits = onlyDigits(newValue.text);
    final cappedDigits = allDigits.length > 11
        ? allDigits.substring(0, 11)
        : allDigits;
    final formatted = formatPhone(cappedDigits);

    int targetOffset = formatted.length;
    if (digitsBeforeCursor == 0) {
      targetOffset = 0;
    } else {
      int seenDigits = 0;
      for (int i = 0; i < formatted.length; i++) {
        final code = formatted.codeUnitAt(i);
        if (code >= 48 && code <= 57) {
          seenDigits++;
          if (seenDigits >= digitsBeforeCursor) {
            targetOffset = i + 1;
            break;
          }
        }
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: targetOffset.clamp(0, formatted.length),
      ),
    );
  }
}

final RegExp _dateOnlyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final RegExp _explicitOffsetPattern = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

/// Converte datas ISO e timestamps UTC da API para o fuso local sem deslocar datas puras (YYYY-MM-DD).
DateTime? parseUtcToLocal(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) {
    return raw.isUtc ? raw.toLocal() : raw;
  }
  final text = raw.toString().trim();
  if (text.isEmpty) return null;

  if (_dateOnlyPattern.hasMatch(text)) {
    final parts = text.split('-');
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }
  }

  final isoCandidate = text.contains(' ') && !text.contains('T')
      ? text.replaceFirst(' ', 'T')
      : text;

  if (_explicitOffsetPattern.hasMatch(isoCandidate)) {
    return DateTime.tryParse(isoCandidate)?.toLocal();
  }

  // Timestamps LocalDateTime sem fuso explícito vindos da API em UTC
  final parsedWithUtc = DateTime.tryParse('${isoCandidate}Z');
  if (parsedWithUtc != null) {
    return parsedWithUtc.toLocal();
  }
  return DateTime.tryParse(isoCandidate)?.toLocal();
}

String formatDateTime(dynamic raw, {String fallback = '-'}) {
  final dt = parseUtcToLocal(raw);
  if (dt == null) return fallback;
  return DateFormat('dd/MM/yyyy HH:mm').format(dt);
}

String formatDate(dynamic raw, {String fallback = '-'}) {
  final dt = parseUtcToLocal(raw);
  if (dt == null) return fallback;
  return DateFormat('dd/MM/yyyy').format(dt);
}

String formatTime(dynamic raw, {String fallback = '-'}) {
  final dt = parseUtcToLocal(raw);
  if (dt == null) return fallback;
  return DateFormat('HH:mm').format(dt);
}

/// Faz o parsing seguro de valores monetários em formato brasileiro ou americano (ex: "R$ 1.250,50" -> 1250.50).
double? parseBrlDouble(String? raw) {
  if (raw == null) return null;
  var cleaned = raw.trim().replaceAll(RegExp(r'[^0-9,.-]'), '');
  if (cleaned.isEmpty) return null;
  if (cleaned.contains(',') && cleaned.contains('.')) {
    if (cleaned.lastIndexOf(',') > cleaned.lastIndexOf('.')) {
      cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else {
      cleaned = cleaned.replaceAll(',', '');
    }
  } else if (cleaned.contains(',')) {
    cleaned = cleaned.replaceAll(',', '.');
  }
  return double.tryParse(cleaned);
}

/// Formata número em moeda brasileira (R$ 1.234,56).
String formatCurrencyBrl(num? value, {String fallback = 'R\$ 0,00'}) {
  if (value == null) return fallback;
  final formatted = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  ).format(value);
  return formatted;
}

/// Realiza busca multi-termo nos valores escalares de um mapa sem serializar JSON em tempo de renderização.
bool matchesSearchRecord(Map<String, dynamic> record, String query) {
  final cleanQuery = query.trim().toLowerCase();
  if (cleanQuery.isEmpty) return true;
  final terms = cleanQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);

  final buffer = StringBuffer();
  void collect(dynamic value, int depth) {
    if (value == null || depth > 3) return;
    if (value is String) {
      if (value.startsWith('data:image/') && value.length > 120) return;
      buffer
        ..write(value.toLowerCase())
        ..write(' ');
    } else if (value is num || value is bool) {
      buffer
        ..write(value.toString().toLowerCase())
        ..write(' ');
    } else if (value is Map) {
      for (final v in value.values) {
        collect(v, depth + 1);
      }
    } else if (value is Iterable) {
      int count = 0;
      for (final item in value) {
        if (count++ >= 20) break;
        collect(item, depth + 1);
      }
    }
  }

  collect(record, 0);
  final haystack = buffer.toString();
  return terms.every(haystack.contains);
}

/// Alias compatível para filtros multi-termo nos módulos do sistema.
bool recordMatchesQuery(Map<String, dynamic> record, String query) =>
    matchesSearchRecord(record, query);
