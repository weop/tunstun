import 'package:flutter/material.dart';

// Flutter only shows the hand cursor over buttons on web; on desktop the
// default is the plain arrow. Tunstun wants the hand on every button.
const ButtonStyle _clickableStyle = ButtonStyle(
  mouseCursor: WidgetStateMouseCursor.clickable,
);

ThemeData buildAppTheme(Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.indigo.shade700,
      brightness: brightness,
    ),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    elevatedButtonTheme: const ElevatedButtonThemeData(style: _clickableStyle),
    textButtonTheme: const TextButtonThemeData(style: _clickableStyle),
    iconButtonTheme: const IconButtonThemeData(style: _clickableStyle),
    popupMenuTheme: const PopupMenuThemeData(
      mouseCursor: WidgetStateMouseCursor.clickable,
    ),
    listTileTheme: const ListTileThemeData(
      mouseCursor: WidgetStateMouseCursor.clickable,
    ),
  );
}
