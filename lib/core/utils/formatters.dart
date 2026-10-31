import 'package:flutter/services.dart';

/// Returns the first name of a full name (or [fallback] when empty).
String firstNameOf(String? fullName, {String fallback = ''}) {
  final trimmed = fullName?.trim() ?? '';
  if (trimmed.isEmpty) return fallback;
  return trimmed.split(RegExp(r'\s+')).first;
}

/// Keeps only the digits of [value].
String onlyDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

/// Formats a Brazilian phone number: `(21) 99999-9999` or `(21) 3333-4444`.
/// Partial numbers are formatted progressively while the user types.
String formatPhone(String? value) {
  final digits = onlyDigits(value ?? '');
  if (digits.isEmpty) return '';
  final limited = digits.length > 11 ? digits.substring(0, 11) : digits;
  final buffer = StringBuffer();
  for (var i = 0; i < limited.length; i++) {
    if (i == 0) buffer.write('(');
    if (i == 2) buffer.write(') ');
    final hyphenAt = limited.length == 11 ? 7 : 6;
    if (i == hyphenAt) buffer.write('-');
    buffer.write(limited[i]);
  }
  return buffer.toString();
}

/// Validates a real Brazilian phone number (DDD + 8 or 9 digits).
/// Returns an error message, or `null` when the number is valid.
String? validatePhone(String? value) {
  final digits = onlyDigits(value ?? '');
  if (digits.isEmpty) return 'Informe um telefone de contato.';
  if (digits.length < 10) return 'Telefone incompleto. Informe DDD + número.';
  final ddd = int.parse(digits.substring(0, 2));
  if (ddd < 11 || digits[1] == '0') return 'DDD inválido.';
  if (digits.length == 11 && digits[2] != '9') {
    return 'Celular deve começar com 9 após o DDD.';
  }
  if (digits.length == 10 && !'2345'.contains(digits[2])) {
    return 'Número de telefone fixo inválido.';
  }
  final subscriber = digits.substring(2);
  if (RegExp(r'^(\d)\1+$').hasMatch(subscriber)) {
    return 'Informe um número de telefone real.';
  }
  return null;
}

/// Input formatter that accepts only digits and shows them as a phone mask.
class PhoneInputFormatter extends TextInputFormatter {
  const PhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = formatPhone(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
