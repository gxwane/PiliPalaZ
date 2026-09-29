import 'package:flutter/material.dart';
import 'package:pilipalaz/utils/feed_back.dart';

class ActionRowItem extends StatelessWidget {
  final Widget? icon;
  final Widget? selectIcon;
  final Function? onTap;
  final bool? loadingStatus;
  final String? text;
  final bool selectStatus;
  final Function? onLongPress;

  const ActionRowItem({
    super.key,
    this.icon,
    this.selectIcon,
    this.onTap,
    this.loadingStatus,
    this.text,
    this.selectStatus = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selectStatus
          ? Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.6)
          : Theme.of(context).highlightColor.withValues(alpha: 0.2),
      borderRadius: const BorderRadius.all(Radius.circular(30)),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => {feedBack(), onTap!()},
        onLongPress: () {
          feedBack();
          if (onLongPress != null) {
            onLongPress!();
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 7, 15, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                IconTheme(
                  data: IconThemeData(
                    size: 13,
                    color: selectStatus
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  child: icon!,
                ),
                const SizedBox(width: 6),
              ],
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
                          : null,
                      fontSize: Theme.of(
                        context,
                      ).textTheme.labelMedium!.fontSize,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
