import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NoData extends StatelessWidget {
  const NoData({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset("assets/images/error.svg", height: 200),
            const SizedBox(height: 20),
            Text(
              message ?? '没有数据',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}
