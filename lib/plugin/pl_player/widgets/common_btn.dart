import 'package:flutter/material.dart';

class ComBtn extends StatelessWidget {
  final Widget? icon;
  final Function? fuc;
  final String? semanticsLabel;
  final String? hint;

  const ComBtn({
    this.icon,
    this.fuc,
    this.semanticsLabel,
    this.hint,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      hint: hint,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: InkWell(
          onTap: () {
            fuc?.call();
          },
          child: Center(
            child: SizedBox(
              width: 34,
              height: 34,
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }
}
