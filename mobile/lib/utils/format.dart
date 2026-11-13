import 'package:intl/intl.dart';

String quantity(dynamic n) =>
    NumberFormat.decimalPattern('tr_TR').format(n ?? 0);
String dateTime(dynamic raw) {
  final date = DateTime.tryParse(raw?.toString() ?? '');
  return date == null
      ? '—'
      : DateFormat(
          'dd.MM.yyyy • HH:mm',
          'tr_TR',
        ).format(date.toUtc().add(const Duration(hours: 3)));
}

String dateOnly(dynamic raw) {
  final date = DateTime.tryParse(raw?.toString() ?? '');
  return date == null
      ? 'SKT yok'
      : DateFormat('dd.MM.yyyy', 'tr_TR').format(date);
}

String statusLabel(String value) => switch (value) {
  'Pending' => 'Bekliyor',
  'Approved' => 'Onaylandı',
  'Preparing' => 'Hazırlanıyor',
  'Delivered' => 'Teslim edildi',
  'Cancelled' => 'İptal edildi',
  _ => value,
};
String movementLabel(String v) => switch (v) {
  'In' => 'Giriş',
  'Out' => 'Çıkış',
  'Delivery' => 'Talep teslimi',
  'Correction' => 'Düzeltme',
  'Return' => 'İade',
  'Count' => 'Sayım farkı',
  _ => v,
};
String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'Bu alan zorunludur.' : null;
String? positiveNumber(String? value) {
  final n = int.tryParse(value ?? '');
  return n == null || n <= 0 || n > 10000000
      ? '1–10.000.000 arasında tam sayı girin.'
      : null;
}
