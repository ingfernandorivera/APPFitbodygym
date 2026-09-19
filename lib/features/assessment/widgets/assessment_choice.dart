import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class AssessmentChoice extends StatelessWidget {
  const AssessmentChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.badge,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? subtitle;
  final IconData? icon;
  final String? badge;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? AppColors.surfaceHigh : AppColors.inputFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AppColors.brand : AppColors.outline,
          width: selected ? 2 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.brand.withValues(alpha: 0.18)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppColors.brand
                            : AppColors.outline.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 24,
                      color: selected ? AppColors.brand : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: selected
                                  ? AppColors.textPrimary
                                  : AppColors.textPrimary.withValues(
                                      alpha: 0.9,
                                    ),
                            ),
                          ),
                          if (badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brand.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                badge!,
                                style: const TextStyle(
                                  color: AppColors.brand,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            color: selected
                                ? AppColors.textMuted
                                : AppColors.textMuted.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.brand : Colors.transparent,
                    border: Border.all(
                      color: selected ? AppColors.brand : AppColors.outline,
                      width: selected ? 2 : 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AssessmentBody extends StatelessWidget {
  const AssessmentBody({
    super.key,
    this.fullness = .5,
    this.representation = 'Neutral',
  });

  final double fullness;
  final String representation;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Silueta corporal esquemática. No representa una medición.',
    child: Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 220,
            width: 170,
            child: CustomPaint(painter: _BodyPainter(fullness, representation)),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outline),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Silueta esquemática · Orientativa, no diagnóstica',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _BodyPainter extends CustomPainter {
  const _BodyPainter(this.fullness, this.representation);
  final double fullness;
  final String representation;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 170, size.height / 220);

    final bgGlow = Paint()
      ..shader = RadialGradient(
        colors: [AppColors.brand.withValues(alpha: 0.12), Colors.transparent],
      ).createShader(const Rect.fromLTWH(0, 0, 170, 220));
    canvas.drawCircle(const Offset(85, 110), 80, bgGlow);

    final fill = Paint()..color = AppColors.brandDark;
    final stroke = Paint()
      ..color = AppColors.brand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final subtleLine = Paint()
      ..color = AppColors.brand.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Cabeza estilizada
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(85, 24), width: 28, height: 32),
      fill,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(85, 24), width: 28, height: 32),
      stroke,
    );

    final spread = fullness.clamp(0.0, 1.0) * 16;
    final shoulders = representation == 'Hombros amplios' ? 10.0 : 0.0;
    final hips = representation == 'Caderas amplias' ? 9.0 : 0.0;

    // Cuerpo principal
    final body = Path()
      // Cuello
      ..moveTo(77, 40)
      // Clavícula y hombro izquierdo
      ..quadraticBezierTo(70, 42, 58 - shoulders, 50)
      ..quadraticBezierTo(48 - shoulders, 58, 44 - shoulders, 68)
      // Brazo izquierdo exterior
      ..lineTo(32 - shoulders, 114)
      ..quadraticBezierTo(28 - shoulders, 126, 38 - shoulders, 126)
      // Antebrazo interior
      ..lineTo(51, 88)
      // Costado y cintura izquierda
      ..quadraticBezierTo(58 - spread, 106, 56 - spread - hips, 130)
      // Pierna izquierda exterior
      ..lineTo(60 - hips, 196)
      // Pie izquierdo
      ..quadraticBezierTo(66, 206, 74, 196)
      // Pierna interior y entrepierna
      ..lineTo(82, 142)
      // Entrepierna a pierna derecha interior
      ..lineTo(88, 142)
      ..lineTo(96, 196)
      // Pie derecho
      ..quadraticBezierTo(104, 206, 110 + hips, 196)
      // Pierna derecha exterior
      ..lineTo(114 + spread + hips, 130)
      // Cintura y costado derecho
      ..quadraticBezierTo(112 + spread, 106, 119, 88)
      // Brazo derecho interior
      ..lineTo(132 + shoulders, 126)
      ..quadraticBezierTo(142 + shoulders, 126, 138 + shoulders, 114)
      // Brazo derecho exterior y hombro
      ..lineTo(126 + shoulders, 68)
      ..quadraticBezierTo(122 + shoulders, 58, 112 + shoulders, 50)
      ..quadraticBezierTo(100, 42, 93, 40)
      ..close();

    canvas.drawPath(body, fill);
    canvas.drawPath(body, stroke);

    // Líneas deportivas estilizadas interiores (pecho y torso)
    canvas.drawLine(const Offset(68, 68), const Offset(82, 74), subtleLine);
    canvas.drawLine(const Offset(102, 68), const Offset(88, 74), subtleLine);
    canvas.drawLine(const Offset(85, 78), const Offset(85, 112), subtleLine);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BodyPainter oldDelegate) =>
      fullness != oldDelegate.fullness ||
      representation != oldDelegate.representation;
}
