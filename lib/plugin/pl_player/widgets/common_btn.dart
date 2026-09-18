import 'package:flutter/material.dart';

class ComBtn extends StatelessWidget {
  final Widget? icon;
  final Function? fuc;
  final String? semanticsLabel;
  final String? hint;
  final Color? backgroundColor;
  final ShapeBorder? shape;
  final double size;

  const ComBtn({
    this.icon,
    this.fuc,
    this.semanticsLabel,
    this.hint,
    this.backgroundColor,
    this.shape,
    this.size = 48.0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasBackground = backgroundColor != null;
    final ShapeBorder effectiveShape =
        shape ??
        (hasBackground ? const CircleBorder() : const RoundedRectangleBorder());

    return Semantics(
      button: true,
      label: semanticsLabel,
      hint: hint,
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          type: hasBackground ? MaterialType.canvas : MaterialType.transparency,
          color: backgroundColor,
          shape: effectiveShape,
          clipBehavior: hasBackground ? Clip.antiAlias : Clip.none,
          child: InkWell(
            customBorder: effectiveShape,
            onTap: () {
              fuc?.call();
            },
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}
