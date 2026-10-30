import 'package:flutter/widgets.dart';

import 'motion.dart';

/// Content that arrives: fades up into place once, then is just its child.
///
/// `TweenAnimationBuilder` has no way to say "start later" without a timer, and a
/// `Future.delayed` in `initState` leaves a pending timer behind at the end of a
/// widget test. Both are avoided by running one controller across
/// `delay + duration` and letting the child read a slice of it with [Interval]: the
/// group is one finite animation, it settles, and `pumpAndSettle` returns.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = Motion.entrance,
    this.rise = Motion.rise,
    this.curve = Motion.standard,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Pixels below the final position at the start. Zero keeps it a pure fade.
  final double rise;
  final Curve curve;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animatable<double> _slice;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.duration;
    // Nothing here reads the widget tree: `MediaQuery.of` in `initState` is an
    // error, because depending on an inherited widget is exactly what has not
    // happened yet. Whether to animate is decided on the first build, and the
    // controller starts paused so a reduce-motion build never sees a frame of
    // movement.
    _controller = AnimationController(
      vsync: this,
      duration: total > Duration.zero ? total : Duration.zero,
      value: 0,
    );
    _slice = Tween<double>(begin: 0, end: 1).chain(
      CurveTween(
        curve: total > Duration.zero
            ? Interval(
                widget.delay.inMilliseconds / total.inMilliseconds,
                1.0,
                curve: widget.curve,
              )
            : const Interval(1.0, 1.0),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) {
      _started = true;
      if (Motion.enabled(context)) {
        _controller.forward();
      } else {
        _controller.value = 1;
      }
    }
    final t = _slice.evaluate(_controller);
    if (t >= 1.0) return widget.child;
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - t) * widget.rise),
        child: widget.child,
      ),
    );
  }
}

/// A number that counts to its value instead of appearing.
///
/// Metrics are where motion pays for itself. A KPI that animates up from zero tells
/// the eye where to look, and when the figure later *changes* under a live update the
/// tween is what makes the change noticeable: 166 quietly becoming 266 is not seen,
/// 166 → 266 over 750ms is.
///
/// The child is built from a `num` so the caller keeps the formatting. Nothing here
/// invents a number format - the app already has `LimsFormatters`, and a second
/// formatter inside a motion widget is how one screen ends up with two spellings of
/// the same figure.
class CountUp extends StatefulWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.builder,
    this.duration = Motion.count,
    this.curve = Motion.standard,
  });

  final num value;
  final Widget Function(num value) builder;
  final Duration duration;
  final Curve curve;

  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animatable<double> _curve;
  bool _started = false;
  double _from = 0;
  double _to = 0;

  @override
  void initState() {
    super.initState();
    _to = widget.value.toDouble();
    // Paused until the first build, which is where reduce-motion is read from
    // (see the note in [_EntranceState.initState]).
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _curve = Tween<double>(begin: 0, end: 1).chain(
      CurveTween(curve: widget.curve),
    );
  }

  @override
  void didUpdateWidget(CountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    final shown = _shown;
    _to = widget.value.toDouble();
    if (_controller.duration == Duration.zero) {
      _from = _to;
      return;
    }
    _from = shown;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _shown => _from + (_to - _from) * _curve.evaluate(_controller);

  @override
  Widget build(BuildContext context) {
    if (!_started) {
      _started = true;
      if (Motion.enabled(context) && widget.duration > Duration.zero) {
        _controller.forward();
      } else {
        _from = _to;
        _controller.value = 1;
      }
    }
    final whole = _to == _to.roundToDouble();
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => widget.builder(whole ? _shown.roundToDouble() : _shown),
    );
  }
}

/// One chart bar, growing from the baseline - optionally after a delay so a series
/// can arrive left to right instead of all at once.
///
/// The chart already animated its bars, but every bar started on the same frame, so
/// a week of sales appeared as one block. Sequenced, the eye follows the shape.
class GrowFraction extends StatefulWidget {
  const GrowFraction({
    super.key,
    required this.value,
    required this.builder,
    this.delay = Duration.zero,
    this.duration = Motion.entrance,
    this.curve = Motion.standard,
  });

  /// Fraction of the final size, 0..1.
  final double value;
  final Widget Function(double fraction) builder;
  final Duration delay;
  final Duration duration;
  final Curve curve;

  @override
  State<GrowFraction> createState() => _GrowFractionState();
}

class _GrowFractionState extends State<GrowFraction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Not `final`: when the underlying figure changes - a week becoming a month - the
  /// bar has to tween from where it is standing to the new height, which means a new
  /// tween. A `late final` field here compiled happily and threw
  /// `LateInitializationError` the first time a bar's value moved, because the second
  /// assignment happens only on a path no test had exercised.
  late Animatable<double> _slice;
  bool _started = false;
  bool _canAnimate = false;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.duration;
    _controller = AnimationController(
      vsync: this,
      duration: total > Duration.zero ? total : Duration.zero,
      value: 0,
    );
    _slice = Tween<double>(begin: 0, end: widget.value).chain(
      CurveTween(
        curve: total > Duration.zero
            ? Interval(
                widget.delay.inMilliseconds / total.inMilliseconds,
                1.0,
                curve: widget.curve,
              )
            : const Interval(1.0, 1.0),
      ),
    );
  }

  @override
  void didUpdateWidget(GrowFraction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    final shown = _slice.evaluate(_controller);
    _slice = Tween<double>(begin: shown, end: widget.value)
        .chain(CurveTween(curve: widget.curve));
    if (_canAnimate) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) {
      _started = true;
      _canAnimate = Motion.enabled(context);
      if (_canAnimate) {
        _controller.forward();
      } else {
        _controller.value = 1;
      }
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => widget.builder(_slice.evaluate(_controller)),
    );
  }
}

/// The press itself. Controls that do not react to a finger are the single clearest
/// tell of a cheap app: the tap "works", so the eye assumes nothing happened.
///
/// Deliberately does not paint a ripple: the screens already use `InkWell` in a few
/// places and a second feedback layer on top of it looks like two widgets pressed at
/// once. Use this where there is no Material surface to borrow.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = Motion.pressScale,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down == v || !mounted) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        child: AnimatedScale(
          duration: Motion.d(context, Motion.tap),
          curve: Motion.standard,
          scale: (_down && enabled) ? widget.scale : 1.0,
          child: widget.child,
        ),
      ),
    );
  }
}

/// A cross-fade between two bodies of the same slot - a tab's content, a chart's
/// detail line, an empty state becoming data.
class FadeSwap extends StatelessWidget {
  const FadeSwap({
    super.key,
    required this.child,
    this.duration = Motion.state,
    this.alignment = Alignment.center,
  });

  /// Re-key the [child] (by ValueKey/UniqueKey) to make it swap.
  final Widget child;
  final Duration duration;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: AnimatedSwitcher(
      duration: Motion.d(context, duration),
      switchInCurve: Motion.standard,
      switchOutCurve: Motion.inOut,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
      ),
    );
  }
}
