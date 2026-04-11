import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/quality/services/quality_service.dart';
import 'package:mes_client/features/production/presentation/production_repair_orders_page.dart';

class QualityRepairOrdersPage extends StatelessWidget {
  const QualityRepairOrdersPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canComplete,
    required this.canExport,
    this.jumpPayloadJson,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canComplete;
  final bool canExport;
  final String? jumpPayloadJson;
  final QualityService? service;

  @override
  Widget build(BuildContext context) {
    return ProductionRepairOrdersPage(
      session: session,
      onLogout: onLogout,
      canComplete: canComplete,
      canExport: canExport,
      jumpPayloadJson: jumpPayloadJson,
      service: service ?? QualityService(session),
    );
  }
}
