import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/utils/utils.dart';

import '../../../common/constants.dart';
import 'additional_panel.dart';
import 'pic_panel.dart';

Widget articlePanel(item, context, {floor = 1}) {
  TextStyle authorStyle = TextStyle(
    color: Theme.of(context).colorScheme.primary,
  );

  var major = item.modules?.moduleDynamic?.major;
  if (major == null) return const SizedBox();

  String title = '';
  String summary = '';
  if (major.opus != null) {
    title = major.opus!.title ?? '';
    if (major.opus!.summary?.text != 'undefined' &&
        major.opus!.summary?.richTextNodes?.isNotEmpty == true) {
      summary = major.opus!.summary!.richTextNodes!.first.text ?? '';
    }
  } else if (major.article != null) {
    title = major.article!.title ?? '';
    summary = major.article!.desc ?? '';
  }

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: StyleString.safeSpace),
    child: Column(
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
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        if (summary.isNotEmpty) ...[
          Text(
            summary,
            maxLines: 6,
            style: const TextStyle(height: 1.55),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
        ],
        picWidget(item, context),
        if (item?.modules?.moduleDynamic?.additional != null)
          addWidget(
            item,
            context,
            item.modules.moduleDynamic.additional.type,
            floor: floor,
          ),
      ],
    ),
  );
}
