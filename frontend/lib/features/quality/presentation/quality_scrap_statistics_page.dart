import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/quality/presentation/widgets/quality_scrap_statistics_page_header.dart';
import 'package:mes_client/features/quality/services/quality_service.dart';
import 'package:mes_client/features/production/presentation/production_scrap_statistics_page.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: QualityScrapStatisticsPageHeader(),
        ),
        Expanded(
          child: ProductionScrapStatisticsPage(
            session: session,
            onLogout: onLogout,
            canExport: canExport,
            jumpPayloadJson: jumpPayloadJson,
            service: service ?? QualityService(session),
          ),
        ),
      ],
    );
  }
}
