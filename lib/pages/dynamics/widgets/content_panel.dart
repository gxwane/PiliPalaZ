// 内容
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'nine_grid_gallery.dart';
import 'rich_node_panel.dart';

// ignore: must_be_immutable
class Content extends StatefulWidget {
  dynamic item;
  String? source;
  String? heroTag;
  Content({super.key, this.item, this.source, this.heroTag});

  @override
  State<Content> createState() => _ContentState();
}

class _ContentState extends State<Content> {
  late bool hasPics;
  List<dynamic> pics = [];

  @override
  void initState() {
    super.initState();
    final major = widget.item.modules?.moduleDynamic?.major;
    hasPics =
        major != null &&
        ((major.opus != null && major.opus.pics.isNotEmpty) ||
            (major.article != null &&
                (major.article.covers?.isNotEmpty ?? false)));
    if (hasPics) {
      if (major?.opus != null && major!.opus.pics.isNotEmpty) {
        pics = widget.item.modules.moduleDynamic.major.opus.pics;
      } else if (major?.article != null &&
          (major!.article.covers?.isNotEmpty ?? false)) {
        pics = major.article.covers;
      }
    }
  }

  InlineSpan picsNodes() {
    if (pics.isEmpty) return const TextSpan();
    final String dynamicId =
        (widget.item.idStr ?? widget.item.basic?.commentIdStr ?? '').toString();

    return WidgetSpan(
      child: NineGridGallery(
        items: pics,
        sourceScope: 'content_panel',
        dynamicId: dynamicId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    TextStyle authorStyle = TextStyle(
      color: Theme.of(context).colorScheme.primary,
    );
    InlineSpan? richNodes = richNode(widget.item, context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.item.modules.moduleDynamic.topic != null) ...[
            GestureDetector(
              onTap: () {
                final topic = widget.item.modules.moduleDynamic.topic.name;
                if (topic != null && topic.isNotEmpty) {
                  Get.toNamed('/searchResult', parameters: {'keyword': topic});
                }
              },
              child: Text(
                '#${widget.item.modules.moduleDynamic.topic.name}',
                style: authorStyle,
              ),
            ),
          ],
          if (richNodes != null)
            widget.source == 'detail'
                ? SelectableRegion(
                    magnifierConfiguration: const TextMagnifierConfiguration(),
                    focusNode: FocusNode(),
                    selectionControls: MaterialTextSelectionControls(),
                    child: Text.rich(
                      richNodes,
                      maxLines: 999,
                      overflow: TextOverflow.fade,
                    ),
                  )
                : Text.rich(
                    richNodes,
                    maxLines: 6,
                    overflow: TextOverflow.fade,
                  ),
          if (hasPics) ...[
            Text.rich(
              picsNodes(),
              // semanticsLabel: '动态图片',
            ),
          ],
        ],
      ),
    );
  }
}
