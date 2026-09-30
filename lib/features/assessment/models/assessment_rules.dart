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
    if (estimate <= 17) return 'assets/images/body_fat/female_14_17.jpg';
    if (estimate <= 21) return 'assets/images/body_fat/female_18_21.jpg';
    if (estimate <= 25) return 'assets/images/body_fat/female_22_25.jpg';
    if (estimate <= 29) return 'assets/images/body_fat/female_26_29.jpg';
    if (estimate <= 34) return 'assets/images/body_fat/female_30_34.jpg';
    if (estimate <= 39) return 'assets/images/body_fat/female_35_39.jpg';
    if (estimate <= 45) return 'assets/images/body_fat/female_40_45.jpg';
    return 'assets/images/body_fat/female_46_plus.jpg';
  } else {
    if (estimate <= 11) return 'assets/images/body_fat/male_08_11.jpg';
    if (estimate <= 15) return 'assets/images/body_fat/male_12_15.jpg';
    if (estimate <= 19) return 'assets/images/body_fat/male_16_19.jpg';
    if (estimate <= 24) return 'assets/images/body_fat/male_20_24.jpg';
    if (estimate <= 29) return 'assets/images/body_fat/male_25_29.jpg';
    if (estimate <= 34) return 'assets/images/body_fat/male_30_34.jpg';
    if (estimate <= 40) return 'assets/images/body_fat/male_35_40.jpg';
    return 'assets/images/body_fat/male_41_plus.jpg';
  }
}
