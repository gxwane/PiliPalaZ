import 'package:flutter/material.dart';
import 'package:pilipalaz/utils/utils.dart';

class StatView extends StatelessWidget {
  final String? theme;
  final dynamic view;
  final String? size;
  final String? goto;

  const StatView({super.key, this.theme, this.view, this.size, this.goto});

  @override
  Widget build(BuildContext context) {
    Map<String, Color> colorObject = {
      'white': Colors.white,
      'gray': Theme.of(context).colorScheme.outline.withValues(alpha: 0.8),
      'black': Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
    };
    Color color = colorObject[theme]!;
    return Row(
      children: [
        Icon(
          goto == 'picture'
              ? Icons.remove_red_eye_outlined
              : Icons.play_circle_outlined,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 2),
        Text(
          Utils.numFormat(view!),
          style: TextStyle(fontSize: size == 'medium' ? 12 : 11, color: color),
          overflow: TextOverflow.clip,
          semanticsLabel:
              '${Utils.numFormat(view!)}次${goto == "picture" ? "浏览" : "播放"}',
        ),
      ],
    );
  }
}
