import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/core/ui/primitives/mes_gap.dart';
import 'package:mes_client/core/ui/primitives/mes_status_chip.dart';
import 'package:mes_client/core/ui/primitives/mes_surface.dart';

void main() {
  testWidgets('MesSurface 使用统一圆角与内边距', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: const Scaffold(
          body: MesSurface(
            padding: EdgeInsets.all(16),
            child: Text('surface-body'),
          ),
        ),
      ),
    );

    expect(find.text('surface-body'), findsOneWidget);

    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(MesSurface),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.borderRadius, BorderRadius.circular(16));
  });

  testWidgets('MesStatusChip 渲染状态文案', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: Scaffold(
          body: Row(
            children: [
              MesStatusChip.success(label: '已启用'),
              MesGap.horizontal(12),
              MesStatusChip.warning(label: '待确认'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('已启用'), findsOneWidget);
    expect(find.text('待确认'), findsOneWidget);
  });
}
