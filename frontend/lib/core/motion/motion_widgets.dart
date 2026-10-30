import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
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
    // The controller is built without consulting the widget tree, and it starts
    // paused. Reading an inherited widget from `initState` is an error, and starting
    // from `build` is a side effect in a method that may run for reasons unrelated to
    // arrival. `didChangeDependencies` is the one place both are legal, and it runs
    // before the first frame is painted.
    final total = widget.delay + widget.duration;
    _controller = AnimationController(
      vsync: this,
      duration: widget.delay + widget.duration,
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.enabled(context)) {
      _controller.forward();
    } else {
      // Arrived, not animated: the child is at its final position on the first
      // frame, which is what "reduced motion" asks for - the alternative reading,
      // "make it faster", leaves a flash nobody asked to see.
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
  bool _canAnimate = false;
  double _from = 0;
  double _to = 0;

  @override
  void initState() {
    super.initState();
    _to = widget.value.toDouble();
    // Paused until didChangeDependencies; see [_EntranceState].
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
    if (_canAnimate) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _shown => _from + (_to - _from) * _curve.evaluate(_controller);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.enabled(context) && widget.duration > Duration.zero) {
      _canAnimate = true;
      _controller.forward();
    } else {
      _from = _to;
      _controller.value = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final whole = _to == _to.roundToDouble();
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) =>
          widget.builder(whole ? _shown.roundToDouble() : _shown),
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _canAnimate = Motion.enabled(context);
    if (_canAnimate) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => widget.builder(_slice.evaluate(_controller)),
    );
  }
}

/// The press itself - and the hover and focus that come with it.
///
/// Controls that do not react to a finger are the clearest tell of a cheap app: the
/// tap "works", so the eye assumes nothing happened. This one also answers a mouse
/// and a keyboard, because the admin screen is used on a PC all day and a control
/// that only acknowledges touch is half-finished there.
///
/// Deliberately does not paint a ripple: the screens already use `InkWell` in places,
/// and two feedback layers on top of each other look like two widgets were pressed.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = Motion.pressScale,
    this.semanticLabel,
    this.selected = false,
    this.focusNode,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final String? semanticLabel;

  /// For controls that are selectable - a chart bar holding the selection, a filter
  /// chip that is on. Losing this in a refactor would leave the control announced as a
  /// plain button, and a screen reader user tapping "the selected day" would get no
  /// answer to the question they asked.
  final bool selected;
  final FocusNode? focusNode;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _hover = false;
  bool _focus = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _set(bool v) {
    if (!mounted || _down == v) return;
    setState(() => _down = v);
  }

  void _activate() {
    final onTap = widget.onTap;
    if (onTap != null) {
      onTap();
    } else {
      widget.onLongPress?.call();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_enabled || event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      _activate();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // Hover lifts, press sinks. Two different magnitudes so the two states are not
    // the same news: 1.01 for "I am over this", 0.97 for "I am pressing it".
    final scale = !_enabled
        ? 1.0
        : _down
            ? widget.scale
            : (_hover ? 1.012 : 1.0);
    return Focus(
      focusNode: widget.focusNode,
      canRequestFocus: _enabled,
      onFocusChange: (has) {
        if (mounted) setState(() => _focus = has);
      },
      onKeyEvent: _onKey,
      child: MouseRegion(
        cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) {
          if (mounted) setState(() => _hover = true);
        },
        onExit: (_) {
          if (!mounted) return;
          setState(() {
            _hover = false;
            // A pointer that leaves while held is a cancelled press, not a
            // completed one; leaving `_down` true would keep the control sunk.
            _down = false;
          });
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onTapDown: _enabled ? (_) => _set(true) : null,
          onTapUp: (_) => _set(false),
          onTapCancel: () => _set(false),
          child: Semantics(
            button: _enabled,
            enabled: _enabled,
            selected: widget.selected,
            label: widget.semanticLabel,
            // The focus ring is drawn by the caller's decoration; this only reports
            // the state so a keyboard user sees something move.
            child: AnimatedScale(
              duration: Motion.d(context, _focus ? Motion.state : Motion.tap),
              curve: Motion.standard,
              scale: scale,
              child: widget.child,
            ),
          ),
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
    return AnimatedSwitcher(
      duration: Motion.d(context, duration),
      switchInCurve: Motion.standard,
      switchOutCurve: Motion.inOut,
      // During a swap there are two children, and by default `AnimatedSwitcher`
      // stacks them with StackFit.passthrough - two full-height page bodies inside
      // one slot. That overflowed the shell on a short window. Letting the *outgoing*
      // child be laid out over the incoming one, both unconstrained, keeps the size
      // of the slot equal to the new page instead of the sum of the pair.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topLeft,
        children: <Widget>[...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.015),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// A metric that counts to its value without moving anything around it.
///
/// Two problems this solves that a bare counter does not:
///
/// **Digit width.** A counting figure changes length on the way up - "TZS 900K"
/// passes through strings wider than the answer - and in a Row of KPI tiles that
/// makes the neighbours jitter, which is the one thing that makes a count-up feel
/// cheap instead of premium. The box is sized by the *final* string, laid out
/// invisibly, and the animation is drawn over it. The slot therefore never resizes:
/// mid-flight text that would be wider is clipped rather than pushing the layout, and
/// narrower text simply leaves space.
///
/// **Screen readers.** `AnimatedBuilder` rebuilds the text every frame, so an
/// unwrapped counter announces the figure several times a second while it runs -
/// noise for the person who least needs it. The animated subtree is hidden from
/// semantics and one label carries the final value, so the reader states the answer
/// once.
///
/// Tabular figures are requested as well; they are free where the font supports
/// `tnum` and harmless where it does not, since the sizer already fixes the width.
class MetricText extends StatelessWidget {
  const MetricText({
    super.key,
    required this.display,
    required this.value,
    required this.format,
    this.style,
    this.textAlign = TextAlign.start,
    this.duration,
  });

  /// What the screen shows when the number settles - the caller's own formatted
  /// string, so the animated figure can never disagree with it.
  final String display;
  final num value;
  final String Function(num value) format;
  final TextStyle? style;
  final TextAlign textAlign;
  final Duration? duration;

  static const _tabular = [FontFeature.tabularFigures()];

  @override
  Widget build(BuildContext context) {
    final base = (style ?? const TextStyle()).copyWith(fontFeatures: _tabular);
    final animate = Motion.enabled(context);

    final Widget number = !animate
        ? Text(display, maxLines: 1, style: base)
        : CountUp(
            value: value,
            duration: duration ?? Motion.count,
            builder: (v) => Text(
              format(v),
              maxLines: 1,
              textAlign: textAlign,
              style: base,
              overflow: TextOverflow.clip,
            ),
          );

    // Order matters, and the first version of this had it the wrong way round:
    // `ExcludeSemantics` excludes everything *below* it, so putting the label inside
    // it silenced the metric completely - an accessibility regression that looked like
    // a fix and that no visual check would ever catch.
    return Semantics(
      // The final value, once, instead of a fresh announcement every frame.
      label: display,
      child: ExcludeSemantics(
        child: Stack(
          // The slot is sized by the ANSWER, and the moving figure is placed inside it
          // without being allowed to influence it.
          //
          // `StackFit.loose` with two laid-out children was the first attempt, and it
          // did not work: a loose Stack takes the width of its widest child, so an
          // intermediate "TZS 1715893" still stretched the box past "TZS 4.85M" and
          // the tiles beside it moved anyway. `Positioned` children are the ones that
          // do not participate in sizing, which is what this needs.
          clipBehavior: Clip.hardEdge,
          children: [
            Opacity(
              opacity: 0,
              child: Text(
                display,
                maxLines: 1,
                style: base,
                textAlign: textAlign,
                overflow: TextOverflow.clip,
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: alignmentFor(textAlign),
                child: number,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Which corner the figure sits in while the slot is sized by the answer.
  static Alignment alignmentFor(TextAlign align) => switch (align) {
        TextAlign.right => Alignment.centerRight,
        TextAlign.center => Alignment.center,
        _ => Alignment.centerLeft,
      };
}
