import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/utils/utils.dart';

import 'rich_node_panel.dart';

Widget livePanel(dynamic item, BuildContext context, {int floor = 1}) {
  dynamic content = item.modules.moduleDynamic.major;
  TextStyle authorStyle = TextStyle(
    color: Theme.of(context).colorScheme.primary,
  );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (floor == 2) ...[
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '@${item.modules.moduleAuthor.name}',
                style: authorStyle,
                recognizer: TapGestureRecognizer()
                  ..onTap = () => Get.toNamed(
                    '/member?mid=${item.modules.moduleAuthor.mid}',
                    arguments: {'face': item.modules.moduleAuthor.face},
                  ),
              ),
              const WidgetSpan(child: SizedBox(width: 6)),
              TextSpan(
                text: Utils.dateFormat(item.modules.moduleAuthor.pubTs),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: Theme.of(context).textTheme.labelSmall!.fontSize,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
      const SizedBox(height: 4),
      if (item.modules.moduleDynamic.topic != null) ...[
        Padding(
          padding: floor == 2
              ? EdgeInsets.zero
              : const EdgeInsets.only(left: 12, right: 12),
          child: GestureDetector(
            child: Text(
              '#${item.modules.moduleDynamic.topic.name}',
              style: authorStyle,
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
      if (floor == 2 && item.modules.moduleDynamic.desc != null) ...[
        Text.rich(richNode(item, context)!),
        const SizedBox(height: 6),
      ],
      GestureDetector(
        onTap: () {},
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NetworkImgLayer(width: 120, height: 75, src: content.live.cover),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    content.live.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content.live.descFirst,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: Theme.of(
                        context,
                      ).textTheme.labelMedium!.fontSize,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              content.live.badge['text'],
              style: TextStyle(
                fontSize: Theme.of(context).textTheme.labelMedium!.fontSize,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
