import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:reins/Widgets/flexible_text.dart';
import 'package:reins/Widgets/glitch_text.dart';

class ReinsSettings extends StatelessWidget {
  const ReinsSettings({super.key});

  static const _repoUrl = 'https://github.com/CloudCraft-Studio/Xer0';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlitchText(
          'Xer0',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Builder(
          builder: (builderContext) => ListTile(
            leading: Icon(Icons.share),
            title: Text('Share Xer0'),
            subtitle: Text('Share Xer0 with your friends'),
            onTap: () {
              _openShareSheet(builderContext);
            },
          ),
        ),
        ListTile(
          leading: Icon(Icons.code),
          title: Text('Go to Source Code'),
          subtitle: Text('View on GitHub'),
          onTap: () {
            launchUrlString(_repoUrl);
          },
        ),
        ListTile(
          leading: Icon(Icons.star),
          title: Text('Give a Star on GitHub'),
          subtitle: Text('Support the project'),
          onTap: () {
            launchUrlString(_repoUrl);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 5,
          children: [
            const Text("✖️", style: TextStyle(fontSize: 16)),
            FlexibleText(
              "Thanks for using Xer0!",
              textAlign: TextAlign.center,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Based on Reins by İbrahim Çetin · GPL-3.0',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }

  void _openShareSheet(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null) {
      SharePlus.instance.share(
        ShareParams(
          text: 'Check out Xer0!',
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    }
  }
}
