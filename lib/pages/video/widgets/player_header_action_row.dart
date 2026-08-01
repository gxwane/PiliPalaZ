import 'package:flutter/material.dart';

class PlayerHeaderActionRow extends StatelessWidget {
  const PlayerHeaderActionRow({
    required this.backButton,
    required this.homeButton,
    required this.isEquivalentFullScreen,
    required this.compactActions,
    required this.moreButton,
    this.expandedTitle,
    super.key,
  });

  final Widget backButton;
  final Widget homeButton;
  final bool isEquivalentFullScreen;
  final List<Widget> compactActions;
  final Widget moreButton;
  final Widget? expandedTitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        backButton,
        homeButton,
        if (isEquivalentFullScreen) ...[
          const SizedBox(width: 10),
          Expanded(child: expandedTitle ?? const SizedBox.shrink()),
        ] else ...[
          const Spacer(),
          ...compactActions,
        ],
        moreButton,
      ],
    );
  }
}
