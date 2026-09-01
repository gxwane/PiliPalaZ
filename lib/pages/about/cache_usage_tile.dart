import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pilipalaz/utils/cache_manage.dart';

class CacheUsageTile extends StatefulWidget {
  const CacheUsageTile({
    super.key,
    required this.cacheService,
    required this.onClear,
  });

  final ApplicationCacheService cacheService;
  final Future<bool> Function() onClear;

  @override
  State<CacheUsageTile> createState() => _CacheUsageTileState();
}

class _CacheUsageTileState extends State<CacheUsageTile> {
  Animation<double>? _routeAnimation;
  late String _cacheSizeLabel;
  late bool _hasCacheSize;
  bool _initialRefreshScheduled = false;
  bool _routeCheckScheduled = false;
  bool _clearing = false;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    final cachedBytes = widget.cacheService.cachedApplicationCacheSizeBytes;
    _hasCacheSize = cachedBytes != null;
    _cacheSizeLabel = cachedBytes == null
        ? '计算中…'
        : formatCacheSize(cachedBytes);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialRefreshScheduled) {
      return;
    }
    if (_routeCheckScheduled) {
      return;
    }
    _routeCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeCheckScheduled = false;
      if (!mounted || _initialRefreshScheduled) {
        return;
      }
      final animation = ModalRoute.of(context)?.animation;
      if (animation == null || animation.status == AnimationStatus.completed) {
        _startInitialRefresh();
        return;
      }
      if (identical(_routeAnimation, animation)) {
        return;
      }
      _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
      _routeAnimation = animation;
      animation.addStatusListener(_handleRouteAnimationStatus);
    });
  }

  void _handleRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _startInitialRefresh();
    }
  }

  void _startInitialRefresh() {
    if (_initialRefreshScheduled) {
      return;
    }
    _initialRefreshScheduled = true;
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    _routeAnimation = null;
    unawaited(_refreshCacheSize());
  }

  Future<void> _refreshCacheSize() async {
    final requestGeneration = ++_requestGeneration;
    try {
      final bytes = await widget.cacheService.refreshApplicationCacheSize();
      if (!mounted ||
          requestGeneration != _requestGeneration ||
          bytes == null) {
        return;
      }
      setState(() {
        _hasCacheSize = true;
        _cacheSizeLabel = formatCacheSize(bytes);
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to calculate application cache size: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }
      if (!_hasCacheSize) {
        setState(() => _cacheSizeLabel = '暂时无法读取');
      }
    }
  }

  Future<void> _handleClear() async {
    if (_clearing) {
      return;
    }
    setState(() => _clearing = true);
    _requestGeneration++;
    try {
      final attempted = await widget.onClear();
      if (!mounted || !attempted) {
        return;
      }

      final cachedBytes = widget.cacheService.cachedApplicationCacheSizeBytes;
      setState(() {
        _hasCacheSize = cachedBytes != null;
        _cacheSizeLabel = cachedBytes == null
            ? '计算中…'
            : formatCacheSize(cachedBytes);
      });
      await _refreshCacheSize();
    } catch (error, stackTrace) {
      debugPrint('Failed to run the cache clearing flow: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() => _clearing = false);
      }
    }
  }

  @override
  void dispose() {
    _requestGeneration++;
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = TextStyle(
      fontSize: 13,
      color: Theme.of(context).colorScheme.outline,
    );
    return ListTile(
      onTap: _clearing ? null : _handleClear,
      leading: const Icon(Icons.delete),
      title: const Text('清除缓存'),
      trailing: Text('图片及网络缓存 $_cacheSizeLabel', style: subtitleStyle),
    );
  }
}
