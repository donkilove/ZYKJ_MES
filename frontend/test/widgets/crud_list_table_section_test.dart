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

DataTable _findBodyDataTable(WidgetTester tester) {
  return tester.widgetList<DataTable>(find.byType(DataTable)).firstWhere(
    (table) => table.rows.isNotEmpty,
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

  testWidgets('列表主体组件会为公共 DataTable 注入统一列表行高', (tester) async {
    await tester.pumpWidget(_buildSubject(loading: false, isEmpty: false));
    await tester.pumpAndSettle();

    final bodyTable = _findBodyDataTable(tester);

    expect(bodyTable.dataRowMinHeight, 56);
    expect(bodyTable.dataRowMaxHeight, 72);
  });

  testWidgets('列表主体组件会覆盖页面显式传入的自定义列表行高以保持统一', (tester) async {
    await tester.pumpWidget(
      _buildSubject(
        loading: false,
        isEmpty: false,
        child: DataTable(
          dataRowMinHeight: 32,
          dataRowMaxHeight: 40,
          columns: const [
            DataColumn(label: Text('名称')),
            DataColumn(label: Text('状态')),
          ],
          rows: const [
            DataRow(cells: [DataCell(Text('李四')), DataCell(Text('停用'))]),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bodyTable = _findBodyDataTable(tester);

    expect(bodyTable.dataRowMinHeight, 56);
    expect(bodyTable.dataRowMaxHeight, 72);
  });

  testWidgets('列表主体组件会为所有列注入等宽列宽策略', (tester) async {
    await tester.pumpWidget(
      _buildSubject(
        loading: false,
        isEmpty: false,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('第一列')),
            DataColumn(label: Text('第二列')),
            DataColumn(label: Text('第三列')),
          ],
          rows: const [
            DataRow(
              cells: [
                DataCell(Text('A')),
                DataCell(Text('B')),
                DataCell(Text('C')),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bodyTable = _findBodyDataTable(tester);

    for (final column in bodyTable.columns) {
      expect(column.columnWidth, isA<FixedColumnWidth>());
    }
  });

  testWidgets('列表主体组件会为长文本注入省略样式与完整值提示', (tester) async {
    const longValue = '这是一个非常非常非常长的列表单元格文本，用来验证公共表格会统一省略显示并保留完整提示';

    await tester.pumpWidget(
      _buildSubject(
        loading: false,
        isEmpty: false,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('说明')),
            DataColumn(label: Text('状态')),
          ],
          rows: const [
            DataRow(cells: [DataCell(Text(longValue)), DataCell(Text('正常'))]),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bodyText = tester.widget<Text>(
      find.descendant(
        of: find.byTooltip(longValue),
        matching: find.text(longValue),
      ),
    );

    expect(bodyText.maxLines, 1);
    expect(bodyText.softWrap, false);
    expect(bodyText.overflow, TextOverflow.ellipsis);
  });
}
