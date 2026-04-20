import 'package:flutter/widgets.dart';

class MesGap extends SizedBox {
  const MesGap.vertical(double value, {super.key}) : super(height: value);

  const MesGap.horizontal(double value, {super.key}) : super(width: value);
}
