import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reins/Constants/constants.dart';
import 'package:reins/Utils/material_color_adapter.dart';

/// Cyberpunk seed palette (neon on dark), used by the theme picker.
final Map<String, MaterialColor> kCyberpunkColors = {
  'Cyan': buildMaterialColor(0xFF22D3EE),
  'Magenta': buildMaterialColor(0xFFFF2BD6),
  'Violet': buildMaterialColor(0xFF8B5CF6),
  'Neon': buildMaterialColor(0xFF00FF9C),
  'Blue': buildMaterialColor(0xFF3B82F6),
  'Amber': buildMaterialColor(0xFFF59E0B),
};

class ThemesSettings extends StatefulWidget {
  const ThemesSettings({super.key});

  @override
  State<ThemesSettings> createState() => _ThemesSettingsState();
}

class _ThemesSettingsState extends State<ThemesSettings> {
  final _settingsBox = Hive.box('settings');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Themes',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: ShapeDecoration(
            shape: StadiumBorder(),
            color: Theme.of(context).colorScheme.primaryContainer,
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  radius: MediaQuery.of(context).textScaler.scale(16),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: SvgPicture.asset(
                      AppConstants.appIconSvg,
                      colorFilter: ColorFilter.mode(
                        Theme.of(context).colorScheme.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: Text("Here is your current theme")),
              IconButton(
                icon: Icon(_brightnessIcon),
                iconSize: MediaQuery.of(context).textScaler.scale(24),
                onPressed: () {
                  setState(() => _toggleBrightness());
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final entry in kCyberpunkColors.entries)
              _ThemeButton(
                name: entry.key,
                seedColor: entry.value,
                onPressed: () => _settingsBox.put("color", entry.value),
              ),
          ],
        ),
      ],
    );
  }

  void _toggleBrightness() {
    final currentBrightness = _settingsBox.get('brightness');
    // Brightness: 1 = light, 0 = dark, null = auto
    // Toggle between light, dark, and auto. 1 > 0 > null > 1 > ...
    final nb = currentBrightness == 1 ? 0 : (currentBrightness == 0 ? null : 1);
    _settingsBox.put('brightness', nb);
  }

  IconData get _brightnessIcon {
    final brightness = _settingsBox.get('brightness');
    if (brightness == null) return Icons.radio_button_off;
    return brightness == 1
        ? Icons.light_mode_outlined
        : Icons.dark_mode_outlined;
  }
}

class _ThemeButton extends StatelessWidget {
  final String name;
  final Color seedColor;
  final Function()? onPressed;

  const _ThemeButton({
    required this.name,
    required this.seedColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Theme.of(context).brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
    );

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.surfaceContainer,
        padding: EdgeInsets.all(16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(color: colorScheme.primary),
          ),
          Container(
            height: 20,
            width: 80,
            decoration: ShapeDecoration(
              color: colorScheme.primary,
              shape: StadiumBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 20,
            width: 80,
            decoration: ShapeDecoration(
              color: colorScheme.surface,
              shape: StadiumBorder(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
