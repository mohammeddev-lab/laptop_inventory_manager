import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static const pageTitle = TextStyle(
    fontSize: 28,
    height: 1.2,
    fontWeight: FontWeight.w800,
    color: AppColors.text,
  );
  static const sectionTitle = TextStyle(
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
  static const cardTitle = TextStyle(
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
  static const body = TextStyle(
    fontSize: 14,
    height: 1.45,
    color: AppColors.text,
  );
  static const caption = TextStyle(
    fontSize: 12,
    height: 1.4,
    color: AppColors.secondary,
  );
  static const tableHeader = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.secondary,
  );
  static const tableBody = TextStyle(fontSize: 13, color: AppColors.text);
}
