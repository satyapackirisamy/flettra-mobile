/// Rupee formatting, in one place.
///
/// The API sends prices as strings with two decimals, so a whole-rupee amount
/// arrives as "20000.00". Rendered raw that reads "~₹20000.00" — a tilde, four
/// redundant characters and no thousands separator — and it appeared in four
/// screens with three different spellings, including two side by side on the
/// home screen showing the same ride as "₹20,000" and "~₹20000.00".
String formatRupees(dynamic raw) {
  final value = double.tryParse(raw?.toString() ?? '') ?? 0;
  final whole = value.truncate();
  final digits = whole.abs().toString();
  final out = StringBuffer(whole < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// `₹20,000`, or the fallback when there is no price to show.
String rupeesOr(dynamic raw, String fallback) {
  final value = double.tryParse(raw?.toString() ?? '') ?? 0;
  return value == 0 ? fallback : '₹${formatRupees(raw)}';
}
