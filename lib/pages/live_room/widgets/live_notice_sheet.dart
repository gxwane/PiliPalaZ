import 'package:flutter/material.dart';

void showLiveNoticeSheet(
  BuildContext context, {
  required String title,
  required String desc,
  required String areaName,
  required String parentArea,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1E1E1E),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => LiveNoticeSheet(
      title: title,
      desc: desc,
      areaName: areaName,
      parentArea: parentArea,
    ),
  );
}

class LiveNoticeSheet extends StatelessWidget {
  final String title;
  final String desc;
  final String areaName;
  final String parentArea;

  const LiveNoticeSheet({
    super.key,
    required this.title,
    required this.desc,
    required this.areaName,
    required this.parentArea,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDragHandle(),
            const SizedBox(height: 8),
            _buildHeader(context),
            const SizedBox(height: 12),
            if (parentArea.isNotEmpty || areaName.isNotEmpty) ...[
              _buildAreaTag(),
              const SizedBox(height: 10),
            ],
            _buildContent(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.campaign_outlined,
          color: Colors.orangeAccent,
          size: 20,
        ),
        const SizedBox(width: 8),
        const Text(
          '主播公告与简介',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white70, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildAreaTag() {
    final areaText = parentArea.isNotEmpty && areaName.isNotEmpty
        ? '$parentArea · $areaName'
        : (parentArea.isNotEmpty ? parentArea : areaName);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        areaText,
        style: const TextStyle(color: Color(0xFF81D4FA), fontSize: 12),
      ),
    );
  }

  Widget _buildContent() {
    final cleanDesc = desc.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            cleanDesc.isNotEmpty ? cleanDesc : '暂无主播公告与简介',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
