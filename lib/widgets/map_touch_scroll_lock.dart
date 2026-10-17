import 'package:flutter/material.dart';

/// Prevents a parent [ScrollView] from scrolling while the user interacts with a map.
class MapTouchScrollLock extends StatefulWidget {
  const MapTouchScrollLock({
    super.key,
    required this.scrollController,
    required this.child,
  });

  final ScrollController scrollController;
  final Widget child;

  @override
  State<MapTouchScrollLock> createState() => _MapTouchScrollLockState();
}

class _MapTouchScrollLockState extends State<MapTouchScrollLock> {
  double? _lockedOffset;

  void _lockScroll() {
    if (!widget.scrollController.hasClients) return;
    _lockedOffset = widget.scrollController.offset;
  }

  void _unlockScroll() {
    _lockedOffset = null;
  }

  void _holdScrollPosition() {
    final locked = _lockedOffset;
    if (locked == null || !widget.scrollController.hasClients) return;
    if ((widget.scrollController.offset - locked).abs() > 0.5) {
      widget.scrollController.jumpTo(locked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _lockScroll(),
      onPointerMove: (_) => _holdScrollPosition(),
      onPointerUp: (_) => _unlockScroll(),
      onPointerCancel: (_) => _unlockScroll(),
      child: widget.child,
    );
  }
}
