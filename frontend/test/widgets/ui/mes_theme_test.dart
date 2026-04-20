import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';

class _ThemeProbe extends StatelessWidget {
  const _ThemeProbe();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MesTokens>()!;
    return Column(
      children: [
        Text('spacing:${tokens.spacing.md}', style: tokens.typography.body),
        Card(
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.md),
            child: Text('surface', style: tokens.typography.cardTitle),
          ),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('buildMesTheme 注入 MesTokens 并统一卡片外观', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: const Scaffold(body: _ThemeProbe()),
      ),
    );

    final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
    final tokens = theme.extension<MesTokens>();

    expect(tokens, isNotNull);
    expect(tokens!.spacing.md, 16);
    expect(tokens.radius.md, BorderRadius.circular(16));

    final cardTheme = theme.cardTheme;
    expect(cardTheme.margin, EdgeInsets.zero);
    expect(find.text('spacing:16.0'), findsOneWidget);
  });
}
