import 'package:flutter/material.dart';

abstract final class AppRadius {
  static const small = 6.0;
  static const medium = 10.0;
  static const large = 14.0;
  static const dialog = 16.0;

  static const smallAll = BorderRadius.all(Radius.circular(small));
  static const mediumAll = BorderRadius.all(Radius.circular(medium));
  static const largeAll = BorderRadius.all(Radius.circular(large));
  static const dialogAll = BorderRadius.all(Radius.circular(dialog));
}
