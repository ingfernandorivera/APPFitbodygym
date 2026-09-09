import 'package:flutter/material.dart';

import '../../../shared/presentation/atomic_design/molecules/feature_list_item.dart';
import '../../../shared/presentation/atomic_design/organisms/feature_placeholder_panel.dart';

class GymInfoPage extends StatelessWidget {
  const GymInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPanel(
      icon: Icons.storefront_outlined,
      title: 'Fit Body Gym',
      description:
          'Informacion basica disponible para miembros activos y usuarios registrados.',
      items: [
        FeatureListItem(
          icon: Icons.schedule_outlined,
          title: 'Horarios',
          description:
              'Lunes a viernes: 5:00 a.m. a 9:00 p.m. Sabado: 6:00 a.m. a 5:00 p.m.',
        ),
        FeatureListItem(
          icon: Icons.info_outline,
          title: 'Informacion del gimnasio',
          description:
              'Aqui se mostraran avisos, servicios y datos generales aprobados por Fit Body Gym.',
        ),
        FeatureListItem(
          icon: Icons.share_outlined,
          title: 'Compartir app',
          description:
              'Espacio reservado para invitar a otras personas cuando se publique la app.',
        ),
      ],
    );
  }
}
