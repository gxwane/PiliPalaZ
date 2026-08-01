import 'package:flutter/material.dart';

class AppBarAni extends StatefulWidget implements PreferredSizeWidget {
  const AppBarAni({
    required this.child,
    required this.controller,
    required this.visible,
    this.position,
    super.key,
  });

  final PreferredSizeWidget child;
  final AnimationController controller;
  final bool visible;
  final String? position;

  @override
  Size get preferredSize => child.preferredSize;

  @override
  State<AppBarAni> createState() => _AppBarAniState();
}

class _AppBarAniState extends State<AppBarAni> {
  @override
  void initState() {
    super.initState();
    _syncVisibility(animate: false);
  }

  @override
  void didUpdateWidget(covariant AppBarAni oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _syncVisibility(animate: false);
    } else if (oldWidget.visible != widget.visible) {
      _syncVisibility(animate: true);
    }
  }

  void _syncVisibility({required bool animate}) {
    if (!animate) {
      widget.controller.value = widget.visible ? 0 : 1;
      return;
    }
    if (widget.visible) {
      widget.controller.reverse();
    } else {
      widget.controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position:
          Tween<Offset>(
            begin: Offset.zero,
            end: Offset(0, widget.position! == 'top' ? -1 : 1),
          ).animate(
            CurvedAnimation(parent: widget.controller, curve: Curves.linear),
          ),
      child: Container(
        decoration: BoxDecoration(
          gradient: widget.position! == 'top'
              ? const LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: <Color>[Colors.transparent, Colors.black87],
                  tileMode: TileMode.mirror,
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Colors.transparent, Colors.black87],
                  tileMode: TileMode.mirror,
                ),
        ),
        child: SafeArea(bottom: false, child: widget.child),
      ),
    );
  }
}
