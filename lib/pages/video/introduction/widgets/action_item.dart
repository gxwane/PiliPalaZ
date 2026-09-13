import 'package:flutter/material.dart';
import 'package:pilipalaz/utils/feed_back.dart';

class ActionItem extends StatelessWidget {
  final Icon? icon;
  final Icon? selectIcon;
  final Function? onTap;
  final Function? onLongPress;
  final bool? loadingStatus;
  final String? text;
  final bool selectStatus;
  final String semanticsLabel;

  const ActionItem({
    super.key,
    this.icon,
    this.selectIcon,
    this.onTap,
    this.onLongPress,
    this.loadingStatus,
    this.text,
    this.selectStatus = false,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selectStatus,
        label: (text ?? "") + (selectStatus ? "已" : "") + semanticsLabel,
        hint: onLongPress != null ? "长按一键三连" : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: InkWell(
            onTap: () {
              feedBack();
              onTap?.call();
            },
            onLongPress: () {
              onLongPress?.call();
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  // const SizedBox(height: 2),
                  Icon(
                    selectStatus ? selectIcon!.icon! : icon!.icon!,
                    size: 22,
                    opticalSize: 1,
                    color: selectStatus
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 3),
                  AnimatedOpacity(
                    opacity: loadingStatus! ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: Text(
                        text ?? '',
                        key: ValueKey<String>(text ?? ''),
                        style: TextStyle(
                            color: selectStatus
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                            fontSize: Theme.of(context)
                                .textTheme
                                .labelSmall!
                                .fontSize),
                        semanticsLabel: "",
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }
}
