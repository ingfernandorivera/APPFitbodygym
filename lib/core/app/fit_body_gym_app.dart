import 'package:flutter/material.dart';

import '../navigation/session_gate.dart';
import '../theme/app_theme.dart';

class FitBodyGymApp extends StatelessWidget {
  const FitBodyGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fit Body Gym',
      theme: AppTheme.dark,
      home: const SessionGate(),
    );
  }
}
