import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/quality_service.dart';
import 'production_scrap_statistics_page.dart';

class QualityScrapStatisticsPage extends StatelessWidget {
  const QualityScrapStatisticsPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canExport,
    this.jumpPayloadJson,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canExport;
  final String? jumpPayloadJson;
  final QualityService? service;

  @override
  Widget build(BuildContext context) {
    return ProductionScrapStatisticsPage(
      session: session,
      onLogout: onLogout,
      canExport: canExport,
      jumpPayloadJson: jumpPayloadJson,
      service: service ?? QualityService(session),
    );
  }
}
