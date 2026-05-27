import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:reins/Constants/constants.dart';
import 'package:reins/Widgets/flexible_text.dart';

class OllamaBottomSheetHeader extends StatelessWidget {
  final String title;

  const OllamaBottomSheetHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SvgPicture.asset(
            AppConstants.appIconSvg,
            height: 48,
            colorFilter: ColorFilter.mode(
              Theme.of(context).colorScheme.onSurface,
              BlendMode.srcIn,
            ),
          ),
        ),
        FlexibleText(
          title,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
