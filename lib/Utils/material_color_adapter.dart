import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

class MaterialColorAdapter extends TypeAdapter<MaterialColor> {
  @override
  final typeId = 0;

  @override
  MaterialColor read(BinaryReader reader) {
    return buildMaterialColor(reader.readInt());
  }

  @override
  void write(BinaryWriter writer, MaterialColor obj) {
    writer.writeInt(obj.value);
  }
}

/// Builds a [MaterialColor] from a packed ARGB [value]. The seed value is what
/// drives the app's `ColorScheme.fromSeed`, so the shade map can mirror it.
MaterialColor buildMaterialColor(int value) {
  final color = Color(value);
  return MaterialColor(value, {
    50: color,
    100: color,
    200: color,
    300: color,
    400: color,
    500: color,
    600: color,
    700: color,
    800: color,
    900: color,
  });
}
