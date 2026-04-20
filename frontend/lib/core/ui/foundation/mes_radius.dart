import 'package:flutter/widgets.dart';

@immutable
class MesRadius {
  const MesRadius({required this.sm, required this.md, required this.lg});

  final BorderRadius sm;
  final BorderRadius md;
  final BorderRadius lg;

  static final MesRadius standard = MesRadius(
    sm: BorderRadius.circular(10),
    md: BorderRadius.circular(16),
    lg: BorderRadius.circular(24),
  );
}
