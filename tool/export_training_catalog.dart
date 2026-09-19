import 'dart:convert';
import 'dart:io';
import 'package:fit_body_gym/features/training/data/exercise_catalog.dart';

// Ejecutar con dart tool/export_training_catalog.dart cuando cambie el catálogo.
void main() {
  File('supabase/functions/ai-chat/catalog.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(ExerciseCatalog.exercises.map((e) => e.toJson()).toList())}\n',
  );
}
