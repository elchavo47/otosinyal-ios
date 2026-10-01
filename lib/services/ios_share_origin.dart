import 'package:flutter/widgets.dart';

/// A valid, visible anchor for iPad share sheets, in logical screen points.
/// Do not use Rect.zero: UIKit rejects an empty/out-of-bounds popover anchor.
Rect otoShareOrigin() {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return const Rect.fromLTWH(1, 1, 2, 2);
  final view = views.first;
  final logical = view.physicalSize / view.devicePixelRatio;
  final x = (logical.width / 2).clamp(1.0, logical.width > 2 ? logical.width - 1 : 1.0).toDouble();
  final y = (logical.height / 2).clamp(1.0, logical.height > 2 ? logical.height - 1 : 1.0).toDouble();
  return Rect.fromCenter(center: Offset(x, y), width: 1, height: 1);
}
