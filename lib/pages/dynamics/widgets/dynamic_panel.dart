import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/pages/dynamics/index.dart';
import 'package:pilipalaz/common/widgets/hero_tag_generator.dart';
import 'action_panel.dart';
import 'author_panel.dart';
import 'content_panel.dart';
import 'forward_panel.dart';

class DynamicPanel extends StatelessWidget {
  final dynamic item;
  final String? source;
  DynamicPanel({required this.item, this.source, super.key});
  final DynamicsController _dynamicsController = Get.put(DynamicsController());

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: source == 'detail'
          ? const EdgeInsets.only(bottom: 12)
          : EdgeInsets.zero,
      // decoration: BoxDecoration(
      //   border: Border(
      //     bottom: BorderSide(
      //       width: 8,
      //       color: Theme.of(context).dividerColor.withOpacity(0.05),
      //     ),
      //   ),
      // ),
      child: Material(
        elevation: 0,
        clipBehavior: Clip.hardEdge,
        color: Theme.of(context).cardColor.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        child: HeroTagGenerator(
          builder: (context, heroTag) {
            return InkWell(
              onTap: source == 'detail'
                  ? null
                  : () => _dynamicsController.pushDetail(
                      item,
                      1,
                      heroTag: heroTag,
                    ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                    child: AuthorPanel(item: item),
                  ),
                  if (item!.modules!.moduleDynamic!.desc != null ||
                      item!.modules!.moduleDynamic!.major != null)
                    Content(item: item, source: source, heroTag: heroTag),
                  forWard(
                    item,
                    context,
                    _dynamicsController,
                    source,
                    heroTag: heroTag,
                  ),
                  const SizedBox(height: 2),
                  if (source == null) ActionPanel(item: item),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
