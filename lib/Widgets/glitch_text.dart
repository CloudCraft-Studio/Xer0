import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// Renders [text] with a periodic cyberpunk "glitch" burst: two offset
/// cyan/magenta copies jitter behind the main text for a few frames, then settle.
class GlitchText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const GlitchText(this.text, {super.key, this.style});

  @override
  State<GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<GlitchText> {
  final _rnd = Random();
  Timer? _timer;
  Offset _o1 = Offset.zero;
  Offset _o2 = Offset.zero;
  bool _glitching = false;

  @override
  void initState() {
    super.initState();
    _scheduleNext();
  }

  void _scheduleNext() {
    _timer = Timer(
      Duration(milliseconds: 1800 + _rnd.nextInt(2400)),
      _burst,
    );
  }

  Future<void> _burst() async {
    const frames = 6;
    for (var i = 0; i < frames; i++) {
      if (!mounted) return;
      setState(() {
        _glitching = true;
        _o1 = Offset(_rnd.nextDouble() * 4 - 2, _rnd.nextDouble() * 3 - 1.5);
        _o2 = Offset(_rnd.nextDouble() * 4 - 2, _rnd.nextDouble() * 3 - 1.5);
      });
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted) return;
    setState(() {
      _glitching = false;
      _o1 = Offset.zero;
      _o2 = Offset.zero;
    });
    _scheduleNext();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(widget.style);

    Widget layer(Color color, Offset offset) => Transform.translate(
          offset: offset,
          child: Text(
            widget.text,
            style: base.copyWith(color: color),
            maxLines: 1,
            softWrap: false,
          ),
        );

    return Stack(
      alignment: Alignment.center,
      children: [
        if (_glitching) layer(const Color(0xCC22D3EE), _o1),
        if (_glitching) layer(const Color(0xCCFF2BD6), _o2),
        Text(widget.text, style: base, maxLines: 1, softWrap: false),
      ],
    );
  }
}
