class BodyFatStage {
  const BodyFatStage({
    required this.index,
    required this.rangeLabel,
    required this.category,
    required this.description,
    required this.representativeValue,
    required this.assetPath,
  });

  final int index;
  final String rangeLabel;
  final String category;
  final String description;
  final double representativeValue;
  final String assetPath;
}

const List<BodyFatStage> maleBodyFatStages = [
  BodyFatStage(
    index: 1,
    rangeLabel: '8–11%',
    category: 'Muy Bajo',
    description: 'Abdominales muy marcados y alta definición muscular',
    representativeValue: 10,
    assetPath: 'assets/images/body_fat/male_08_11.jpg',
  ),
  BodyFatStage(
    index: 2,
    rangeLabel: '12–15%',
    category: 'Atlético',
    description: 'Abdominales visibles y cintura estrecha',
    representativeValue: 13,
    assetPath: 'assets/images/body_fat/male_12_15.jpg',
  ),
  BodyFatStage(
    index: 3,
    rangeLabel: '16–19%',
    category: 'Fit',
    description: 'Ligera definición abdominal y complexión firme',
    representativeValue: 17,
    assetPath: 'assets/images/body_fat/male_16_19.jpg',
  ),
  BodyFatStage(
    index: 4,
    rangeLabel: '20–24%',
    category: 'Promedio',
    description: 'Sin definición marcada, silueta equilibrada',
    representativeValue: 22,
    assetPath: 'assets/images/body_fat/male_20_24.jpg',
  ),
  BodyFatStage(
    index: 5,
    rangeLabel: '25–29%',
    category: 'Moderado',
    description: 'Acumulación leve en abdomen y costados',
    representativeValue: 27,
    assetPath: 'assets/images/body_fat/male_25_29.jpg',
  ),
  BodyFatStage(
    index: 6,
    rangeLabel: '30–34%',
    category: 'Alto',
    description: 'Acumulación abdominal redondeada y cintura ancha',
    representativeValue: 32,
    assetPath: 'assets/images/body_fat/male_30_34.jpg',
  ),
  BodyFatStage(
    index: 7,
    rangeLabel: '35–40%',
    category: 'Muy Alto',
    description: 'Mayor volumen en abdomen, pecho y cintura',
    representativeValue: 37,
    assetPath: 'assets/images/body_fat/male_35_40.jpg',
  ),
  BodyFatStage(
    index: 8,
    rangeLabel: '41%+',
    category: 'Obesidad',
    description: 'Alta acumulación corporal general',
    representativeValue: 44,
    assetPath: 'assets/images/body_fat/male_41_plus.jpg',
  ),
];

const List<BodyFatStage> femaleBodyFatStages = [
  BodyFatStage(
    index: 1,
    rangeLabel: '14–17%',
    category: 'Atlética',
    description: 'Abdomen marcado y tono muscular definido',
    representativeValue: 15,
    assetPath: 'assets/images/body_fat/female_14_17.jpg',
  ),
  BodyFatStage(
    index: 2,
    rangeLabel: '18–21%',
    category: 'Fit Definida',
    description: 'Línea abdominal suave y silueta deportiva',
    representativeValue: 19,
    assetPath: 'assets/images/body_fat/female_18_21.jpg',
  ),
  BodyFatStage(
    index: 3,
    rangeLabel: '22–25%',
    category: 'Fit Saludable',
    description: 'Abdomen plano natural y curvas tonificadas',
    representativeValue: 23,
    assetPath: 'assets/images/body_fat/female_22_25.jpg',
  ),
  BodyFatStage(
    index: 4,
    rangeLabel: '26–29%',
    category: 'Promedio',
    description: 'Contorno suave en cintura, cadera y muslos',
    representativeValue: 27,
    assetPath: 'assets/images/body_fat/female_26_29.jpg',
  ),
  BodyFatStage(
    index: 5,
    rangeLabel: '30–34%',
    category: 'Moderado',
    description: 'Acumulación ligera en abdomen bajo y caderas',
    representativeValue: 32,
    assetPath: 'assets/images/body_fat/female_30_34.jpg',
  ),
  BodyFatStage(
    index: 6,
    rangeLabel: '35–39%',
    category: 'Alto',
    description: 'Acumulación visible en zona media, cadera y muslos',
    representativeValue: 37,
    assetPath: 'assets/images/body_fat/female_35_39.jpg',
  ),
  BodyFatStage(
    index: 7,
    rangeLabel: '40–45%',
    category: 'Muy Alto',
    description: 'Mayor volumen en abdomen, cintura y tren inferior',
    representativeValue: 42,
    assetPath: 'assets/images/body_fat/female_40_45.jpg',
  ),
  BodyFatStage(
    index: 8,
    rangeLabel: '46%+',
    category: 'Obesidad',
    description: 'Alta acumulación corporal general',
    representativeValue: 48,
    assetPath: 'assets/images/body_fat/female_46_plus.jpg',
  ),
];

List<BodyFatStage> bodyFatStagesForGender(String gender) =>
    gender.toLowerCase().trim() == 'mujer'
    ? femaleBodyFatStages
    : maleBodyFatStages;

BodyFatStage bodyFatStageFor(String gender, double estimate) {
  final isFemale = gender.toLowerCase().trim() == 'mujer';
  if (isFemale) {
    if (estimate <= 17) return femaleBodyFatStages[0];
    if (estimate <= 21) return femaleBodyFatStages[1];
    if (estimate <= 25) return femaleBodyFatStages[2];
    if (estimate <= 29) return femaleBodyFatStages[3];
    if (estimate <= 34) return femaleBodyFatStages[4];
    if (estimate <= 39) return femaleBodyFatStages[5];
    if (estimate <= 45) return femaleBodyFatStages[6];
    return femaleBodyFatStages[7];
  } else {
    if (estimate <= 11) return maleBodyFatStages[0];
    if (estimate <= 15) return maleBodyFatStages[1];
    if (estimate <= 19) return maleBodyFatStages[2];
    if (estimate <= 24) return maleBodyFatStages[3];
    if (estimate <= 29) return maleBodyFatStages[4];
    if (estimate <= 34) return maleBodyFatStages[5];
    if (estimate <= 40) return maleBodyFatStages[6];
    return maleBodyFatStages[7];
  }
}

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

String bodyFatAssetPath(String gender, double estimate) =>
    bodyFatStageFor(gender, estimate).assetPath;
