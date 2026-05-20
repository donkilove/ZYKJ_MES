const List<String> productionDefectPhenomena = <String>[
  '无法烧录程序',
  '外观不良',
  '无功率输出',
  '输出功率低',
  '无数据接收',
  '电流异常',
  '波特率异常',
  '波形异常',
  '无法进入配置模式',
  '产品灯不良',
];

const Map<String, List<String>> productionDefectReasonCategoryMap =
    <String, List<String>>{
      '来料不良': <String>['晶振不良', '单片机不良', '射频芯片不良', 'PCB不良', 'SMA头不良', '其余器件不良'],
      '加工不良': <String>[
        '虚焊',
        '连锡',
        '器件移位',
        '加工撞件',
        '错件',
        '漏件',
        '反件',
        '少件',
        '外观脏污',
        '其余加工不良',
      ],
      '制程不良': <String>['外观损伤', '焊接不良', '制程撞件', '其余制程不良'],
    };

List<String> productionDefectReasonCategories() {
  return productionDefectReasonCategoryMap.keys.toList(growable: false);
}

List<String> productionDefectReasonsForCategory(String category) {
  return List<String>.unmodifiable(
    productionDefectReasonCategoryMap[category] ?? const <String>[],
  );
}
