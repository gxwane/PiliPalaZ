import 'package:flutter/material.dart';

import '../../../common/widgets/network_img_layer.dart';
import '../../../models/bangumi/list.dart';
import '../../../models/common/pgc_type.dart';

const double pgcPageHorizontalPadding = 16;

int pgcPosterColumnCount(double viewportWidth) {
  if (viewportWidth < 600) return 3;
  return (viewportWidth / 160).floor().clamp(3, 6);
}

class PgcCategoryBar extends StatelessWidget {
  const PgcCategoryBar({
    super.key,
    required this.selectedType,
    required this.onSelected,
  });

  final PgcCatalogType selectedType;
  final ValueChanged<PgcCatalogType> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: <Widget>[
            for (final PgcCatalogType type in PgcCatalogType.values) ...[
              _PgcCategoryItem(
                key: ValueKey<String>('pgc-category-${type.name}'),
                type: type,
                selected: type == selectedType,
                onTap: () => onSelected(type),
              ),
              if (type != PgcCatalogType.values.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _PgcCategoryItem extends StatelessWidget {
  const _PgcCategoryItem({
    super.key,
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final PgcCatalogType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const Duration animationDuration = Duration(milliseconds: 180);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextStyle textStyle =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  AnimatedDefaultTextStyle(
                    duration: animationDuration,
                    curve: Curves.easeOutCubic,
                    style: textStyle.copyWith(
                      color: selected
                          ? colors.primary
                          : colors.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    child: Text(type.label),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    key: ValueKey<String>(
                      'pgc-category-indicator-${type.name}',
                    ),
                    duration: animationDuration,
                    curve: Curves.easeOutCubic,
                    width: selected ? 18 : 0,
                    height: 2,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PgcContinueSection extends StatelessWidget {
  const PgcContinueSection({
    super.key,
    required this.title,
    required this.scopeLabel,
    required this.items,
    required this.loading,
    required this.onTap,
    this.errorMessage,
    this.onRetry,
  });

  final String title;
  final String scopeLabel;
  final List<BangumiListItemModel> items;
  final bool loading;
  final ValueChanged<BangumiListItemModel> onTap;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final bool hasError = errorMessage?.isNotEmpty == true;
    if (!loading && items.isEmpty && !hasError) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: pgcPageHorizontalPadding,
            ),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: pgcPageHorizontalPadding,
            ),
            child: Text(
              scopeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (hasError && items.isEmpty)
            _PgcContinueError(onRetry: onRetry)
          else
            SizedBox(
              height: 112,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double cardWidth = (constraints.maxWidth * 0.68)
                      .clamp(248.0, 288.0)
                      .toDouble();
                  final int itemCount = loading && items.isEmpty
                      ? 2
                      : items.length;
                  return ListView.separated(
                    key: const PageStorageKey<String>('pgc-continue-list'),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: pgcPageHorizontalPadding,
                    ),
                    itemCount: itemCount,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (BuildContext context, int index) {
                      if (loading && items.isEmpty) {
                        return PgcContinueSkeletonCard(width: cardWidth);
                      }
                      final BangumiListItemModel item = items[index];
                      return PgcContinueCard(
                        width: cardWidth,
                        item: item,
                        onTap: () => onTap(item),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class PgcContinueCard extends StatelessWidget {
  const PgcContinueCard({
    super.key,
    required this.width,
    required this.item,
    required this.onTap,
  });

  final double width;
  final BangumiListItemModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String progress = _nonEmpty(item.progress) ?? '尚未观看';
    final String update =
        _nonEmpty(item.indexShow) ?? _nonEmpty(item.subTitle) ?? '点击开始观看';
    final String title = _nonEmpty(item.title) ?? '未命名影视';

    return SizedBox(
      width: width,
      height: 112,
      child: Material(
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: <Widget>[
                NetworkImgLayer(
                  src: item.cover,
                  width: 64,
                  height: 96,
                  semanticsLabel: title,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        progress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              update,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: colors.primaryContainer.withValues(
                                alpha: 0.58,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              size: 20,
                              color: colors.primary,
                              semanticLabel: '继续播放',
                            ),
                          ),
                        ],
                      ),
                    ],
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

class PgcContinueSkeletonCard extends StatelessWidget {
  const PgcContinueSkeletonCard({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final Color placeholder = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest;
    return SizedBox(
      width: width,
      height: 112,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: <Widget>[
              Container(
                width: 64,
                height: 96,
                decoration: BoxDecoration(
                  color: placeholder,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(height: 16, color: placeholder),
                    const SizedBox(height: 8),
                    FractionallySizedBox(
                      widthFactor: 0.7,
                      child: Container(height: 12, color: placeholder),
                    ),
                    const Spacer(),
                    FractionallySizedBox(
                      widthFactor: 0.85,
                      child: Container(height: 12, color: placeholder),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PgcCatalogSectionHeader extends StatelessWidget {
  const PgcCatalogSectionHeader({
    super.key,
    required this.title,
    required this.selectedOrder,
    required this.followGroup,
    required this.onOrderSelected,
  });

  final String title;
  final PgcCatalogOrder selectedOrder;
  final PgcFollowGroup followGroup;
  final ValueChanged<PgcCatalogOrder> onOrderSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        pgcPageHorizontalPadding,
        8,
        pgcPageHorizontalPadding,
        10,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          PopupMenuButton<PgcCatalogOrder>(
            key: const ValueKey<String>('pgc-sort-button'),
            tooltip: '排序',
            initialValue: selectedOrder,
            onSelected: onOrderSelected,
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<PgcCatalogOrder>>[
                  for (final PgcCatalogOrder order in PgcCatalogOrder.values)
                    PopupMenuItem<PgcCatalogOrder>(
                      value: order,
                      child: Text(order.labelFor(followGroup)),
                    ),
                ],
            child: Container(
              height: 36,
              padding: const EdgeInsets.only(left: 12, right: 8),
              decoration: BoxDecoration(
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    selectedOrder.labelFor(followGroup),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PgcPosterSkeleton extends StatelessWidget {
  const PgcPosterSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final Color placeholder = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 0.65,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: placeholder,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(height: 14, color: placeholder),
        const SizedBox(height: 5),
        FractionallySizedBox(
          widthFactor: 0.68,
          child: Container(height: 12, color: placeholder),
        ),
      ],
    );
  }
}

class _PgcContinueError extends StatelessWidget {
  const _PgcContinueError({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: pgcPageHorizontalPadding),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '续看内容加载失败',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (onRetry != null)
                  TextButton(onPressed: onRetry, child: const Text('重试')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _nonEmpty(String? value) {
  final String text = value?.trim() ?? '';
  return text.isEmpty ? null : text;
}
