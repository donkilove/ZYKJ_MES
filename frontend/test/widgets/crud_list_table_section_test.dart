import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';

Widget _buildSubject({
  required bool loading,
  required bool isEmpty,
  Widget? child,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 720,
        height: 360,
        child: CrudListTableSection(
          cardKey: const ValueKey('crudListCard'),
          loading: loading,
          isEmpty: isEmpty,
          emptyText: '暂无记录',
          enableUnifiedHeaderStyle: true,
          child:
              child ??
              DataTable(
                columns: const [
                  DataColumn(label: Text('名称')),
                  DataColumn(label: Text('状态')),
                ],
                rows: const [
                  DataRow(cells: [DataCell(Text('张三')), DataCell(Text('启用'))]),
                ],
              ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('列表主体组件在加载态显示进度', (tester) async {
    await tester.pumpWidget(_buildSubject(loading: true, isEmpty: false));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('暂无记录'), findsNothing);
    expect(find.byType(DataTable), findsNothing);
  });

  testWidgets('列表主体组件在空态显示空文案', (tester) async {
    await tester.pumpWidget(_buildSubject(loading: false, isEmpty: true));

    expect(find.text('暂无记录'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(DataTable), findsNothing);
  });

  testWidgets('列表主体组件在内容态显示表格内容', (tester) async {
    await tester.pumpWidget(_buildSubject(loading: false, isEmpty: false));
    await tester.pumpAndSettle();

    expect(find.byType(DataTable), findsNWidgets(2));
    expect(find.text('张三'), findsOneWidget);
    expect(find.text('名称'), findsNWidgets(2));
  });

  testWidgets('列表主体组件在 DataTable 内容态启用固定表头布局', (tester) async {
    await tester.pumpWidget(_buildSubject(loading: false, isEmpty: false));
    await tester.pumpAndSettle();

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(DataTable), findsNWidgets(2));
    expect(find.text('张三'), findsOneWidget);
  });

  testWidgets('列表主体组件默认使用全直角卡片', (tester) async {
    await tester.pumpWidget(_buildSubject(loading: false, isEmpty: false));

    final card = tester.widget<Card>(
      find.byKey(const ValueKey('crudListCard')),
    );
    final shape = card.shape as RoundedRectangleBorder;

    expect(shape.borderRadius, BorderRadius.zero);
    expect(card.clipBehavior, Clip.hardEdge);
  });
}
