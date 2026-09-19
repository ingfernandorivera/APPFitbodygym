double? assessmentNumber(String? input) {
  final value = double.tryParse((input ?? '').trim().replaceAll(',', '.'));
  return value != null && value.isFinite ? value : null;
}

double weightToKg(double value, String unit) =>
    unit == 'lb' ? value / 2.2046226218 : value;

double weightFromKg(double value, String unit) =>
    unit == 'lb' ? value * 2.2046226218 : value;

String? validateAssessmentNumber(
  String? input,
  double min,
  double max, {
  bool integer = false,
}) {
  final value = assessmentNumber(input);
  if (value == null ||
      value < min ||
      value > max ||
      (integer && value != value.truncateToDouble())) {
    return 'Ingresa ${integer ? 'un número entero' : 'un valor'} entre $min y $max.';
  }
  return null;
}

String visualFatRange(double estimate) =>
    '${(estimate - 3).clamp(5, 60).round()}–${(estimate + 3).clamp(5, 60).round()} %';
