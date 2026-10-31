import 'package:flutter/material.dart';

class MembershipStatusCard extends StatelessWidget {
  const MembershipStatusCard({
    super.key,
    required this.name,
    required this.end,
    required this.days,
    required this.active,
    this.authorizedAccess = false,
    this.authorizedAccessExpiresAt,
  }) : message = null;

  const MembershipStatusCard.error(this.message, {super.key})
    : name = '',
      end = null,
      days = -1,
      active = false,
      authorizedAccess = false,
      authorizedAccessExpiresAt = null;

  final String name;
  final DateTime? end;
  final int days;
  final bool active;
  final bool authorizedAccess;
  final DateTime? authorizedAccessExpiresAt;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final warning = active && days <= 7;
    final color = message != null || !active
        ? Colors.redAccent
        : warning
        ? Colors.orangeAccent
        : Colors.greenAccent;
    final title = message != null
        ? 'Atención'
        : authorizedAccess
        ? 'Acceso autorizado'
        : !active
        ? (end == null ? 'Sin membresía vinculada' : 'Membresía inactiva')
        : warning
        ? 'Próxima a vencer'
        : 'Membresía activa';
    final detail =
        message ??
        (authorizedAccess
            ? 'Tienes acceso autorizado a todas las funciones protegidas de la app.'
            : !active
            ? 'Tu membresía no está activa. Conservas acceso a Inicio, evaluación, Info y Perfil; entrenamiento, IA y progreso quedan bloqueados hasta renovar.'
            : warning
            ? 'Tu membresía vence en $days día(s).'
            : 'Tienes acceso a los beneficios de la app.');
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              children: [
                Icon(
                  active && !warning ? Icons.verified : Icons.info_outline,
                  size: 70,
                  color: color,
                ),
                const SizedBox(height: 18),
                if (name.isNotEmpty)
                  Text('Hola, $name', style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.5),
                ),
                if (authorizedAccess && authorizedAccessExpiresAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      'Acceso hasta: ${authorizedAccessExpiresAt!.day.toString().padLeft(2, '0')}/${authorizedAccessExpiresAt!.month.toString().padLeft(2, '0')}/${authorizedAccessExpiresAt!.year}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )
                else if (end != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      'Vencimiento: ${end!.day.toString().padLeft(2, '0')}/${end!.month.toString().padLeft(2, '0')}/${end!.year}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
