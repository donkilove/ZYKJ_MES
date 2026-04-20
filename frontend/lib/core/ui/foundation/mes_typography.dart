import 'package:flutter/material.dart';

@immutable
class MesTypography {
  const MesTypography({
    required this.pageTitle,
    required this.sectionTitle,
    required this.cardTitle,
    required this.body,
    required this.bodyStrong,
    required this.caption,
    required this.metric,
  });

  final TextStyle pageTitle;
  final TextStyle sectionTitle;
  final TextStyle cardTitle;
  final TextStyle body;
  final TextStyle bodyStrong;
  final TextStyle caption;
  final TextStyle metric;

  factory MesTypography.fromTextTheme(TextTheme textTheme) {
    return MesTypography(
      pageTitle: textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w700),
      sectionTitle: textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w700),
      cardTitle: textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600),
      body: textTheme.bodyMedium!,
      bodyStrong: textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
      caption: textTheme.bodySmall!,
      metric: textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
