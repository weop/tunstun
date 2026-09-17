import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// App header logo. assets/logo.svg is drawn for dark surfaces (white fill,
/// black outline), so its colors are inverted when the theme is light.
class HeaderLogo extends StatelessWidget {
  const HeaderLogo({super.key});

  static const ColorFilter _invert = ColorFilter.matrix(<double>[
    -1, 0, 0, 0, 255, //
    0, -1, 0, 0, 255, //
    0, 0, -1, 0, 255, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/logo.svg',
      height: 18,
      semanticsLabel: 'tunstun',
      colorFilter: Theme.of(context).brightness == Brightness.dark
          ? null
          : _invert,
    );
  }
}
