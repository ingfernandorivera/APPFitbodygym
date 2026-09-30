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

String bodyFatAssetPath(String gender, double estimate) {
  final isFemale = gender.toLowerCase().trim() == 'mujer';
  if (isFemale) {
    if (estimate <= 20) return 'assets/images/body_fat/female_14_20.jpg';
    if (estimate <= 25) return 'assets/images/body_fat/female_21_25.jpg';
    if (estimate <= 30) return 'assets/images/body_fat/female_26_30.jpg';
    if (estimate <= 38) return 'assets/images/body_fat/female_31_38.jpg';
    return 'assets/images/body_fat/female_39_plus.jpg';
  } else {
    if (estimate <= 14) return 'assets/images/body_fat/male_10_14.jpg';
    if (estimate <= 19) return 'assets/images/body_fat/male_15_19.jpg';
    if (estimate <= 24) return 'assets/images/body_fat/male_20_24.jpg';
    if (estimate <= 31) return 'assets/images/body_fat/male_25_31.jpg';
    return 'assets/images/body_fat/male_32_plus.jpg';
  }
}
