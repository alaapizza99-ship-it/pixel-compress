import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../l10n.dart';
import '../services/image_service.dart';

enum _Drag { none, move, tl, tr, bl, br }

double _c(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// Full-screen crop editor. Returns the chosen frame as fractions (0..1) of the photo.
class CropEditorScreen extends StatefulWidget {
  final File file;
  final double? aspect; // width / height, null = free
  final Rect? initial; // previous frame as fractions
  const CropEditorScreen(
      {super.key, required this.file, this.aspect, this.initial});

  @override
  State<CropEditorScreen> createState() => _CropEditorScreenState();
}

class _CropEditorScreenState extends State<CropEditorScreen> {
  static const _pad = 20.0;

  CropPreview? _preview;
  bool _failed = false;
  double? _aspect;
  Rect _r = Rect.zero; // frame in preview-pixel units
  _Drag _drag = _Drag.none;
  double _scale = 1; // screen px per preview px

  @override
  void initState() {
    super.initState();
    _aspect = widget.aspect;
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await ImageService.prepareCropPreview(widget.file);
      if (!mounted) return;
      setState(() {
        _preview = p;
        _r = _startRect(p);
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  double get _pw => _preview!.width.toDouble();
  double get _ph => _preview!.height.toDouble();

  Rect _startRect(CropPreview p) {
    final pw = p.width.toDouble(), ph = p.height.toDouble();
    final i = widget.initial;
    if (i != null) {
      return Rect.fromLTRB(i.left * pw, i.top * ph, i.right * pw, i.bottom * ph);
    }
    return _defaultRect(pw, ph, _aspect);
  }

  Rect _defaultRect(double pw, double ph, double? a) {
    if (a == null) return Rect.fromLTWH(pw * .1, ph * .1, pw * .8, ph * .8);
    double w, h;
    if (a >= pw / ph) {
      w = pw * .9;
      h = w / a;
    } else {
      h = ph * .9;
      w = h * a;
    }
    return Rect.fromCenter(center: Offset(pw / 2, ph / 2), width: w, height: h);
  }

  Offset _toImage(Offset local) => (local - const Offset(_pad, _pad)) / _scale;

  void _onStart(DragStartDetails d) {
    final p = _toImage(d.localPosition);
    final reach = 30 / _scale;
    final corners = {
      _Drag.tl: _r.topLeft,
      _Drag.tr: _r.topRight,
      _Drag.bl: _r.bottomLeft,
      _Drag.br: _r.bottomRight,
    };
    _drag = _Drag.none;
    var best = reach;
    corners.forEach((k, c) {
      final dist = (c - p).distance;
      if (dist <= best) {
        best = dist;
        _drag = k;
      }
    });
    if (_drag == _Drag.none && _r.contains(p)) _drag = _Drag.move;
  }

  void _onUpdate(DragUpdateDetails d) {
    if (_drag == _Drag.none) return;
    setState(() {
      if (_drag == _Drag.move) {
        final delta = d.delta / _scale;
        final dx = _c(delta.dx, -_r.left, _pw - _r.right);
        final dy = _c(delta.dy, -_r.top, _ph - _r.bottom);
        _r = _r.shift(Offset(dx, dy));
      } else {
        _resize(_toImage(d.localPosition));
      }
    });
  }

  void _resize(Offset pointer) {
    final pw = _pw, ph = _ph;
    final p = Offset(_c(pointer.dx, 0, pw), _c(pointer.dy, 0, ph));
    final min = math.max(pw, ph) * .06;

    // The corner opposite to the dragged one stays fixed.
    late Offset o;
    late double sx, sy;
    switch (_drag) {
      case _Drag.tl:
        o = _r.bottomRight;
        sx = -1;
        sy = -1;
        break;
      case _Drag.tr:
        o = _r.bottomLeft;
        sx = 1;
        sy = -1;
        break;
      case _Drag.bl:
        o = _r.topRight;
        sx = -1;
        sy = 1;
        break;
      default:
        o = _r.topLeft;
        sx = 1;
        sy = 1;
    }

    final a = _aspect;
    if (a == null) {
      var x = sx > 0 ? math.max(p.dx, o.dx + min) : math.min(p.dx, o.dx - min);
      var y = sy > 0 ? math.max(p.dy, o.dy + min) : math.min(p.dy, o.dy - min);
      x = _c(x, 0, pw);
      y = _c(y, 0, ph);
      _r = Rect.fromPoints(o, Offset(x, y));
    } else {
      final maxW = sx > 0 ? pw - o.dx : o.dx;
      final maxH = sy > 0 ? ph - o.dy : o.dy;
      final upper = math.min(maxW, maxH * a);
      var w = math.max((p.dx - o.dx).abs(), (p.dy - o.dy).abs() * a);
      w = math.min(math.max(w, min), upper);
      final h = w / a;
      _r = Rect.fromPoints(o, Offset(o.dx + sx * w, o.dy + sy * h));
    }
  }

  void _setAspect(double? a) {
    setState(() {
      _aspect = a;
      if (a != null) _r = _defaultRect(_pw, _ph, a);
    });
  }

  void _reset() => setState(() => _r = _defaultRect(_pw, _ph, _aspect));

  void _apply() {
    Navigator.pop(
        context,
        Rect.fromLTRB(
            _r.left / _pw, _r.top / _ph, _r.right / _pw, _r.bottom / _ph));
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('crop_title')),
        actions: [
          TextButton(
              onPressed: p == null ? null : _reset,
              child: Text(context.tr('crop_reset'))),
        ],
      ),
      body: _failed
          ? Center(child: Text(context.tr('crop_error')))
          : p == null
              ? const Center(child: CircularProgressIndicator())
              : Column(children: [
                  Expanded(
                    child: LayoutBuilder(builder: (_, box) {
                      final aw = box.maxWidth - _pad * 2;
                      final ah = box.maxHeight - _pad * 2;
                      _scale = math.min(aw / p.width, ah / p.height);
                      final dw = p.width * _scale, dh = p.height * _scale;
                      final crop = Rect.fromLTRB(_r.left * _scale,
                          _r.top * _scale, _r.right * _scale, _r.bottom * _scale);
                      return Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: _onStart,
                          onPanUpdate: _onUpdate,
                          onPanEnd: (_) => _drag = _Drag.none,
                          child: Padding(
                            padding: const EdgeInsets.all(_pad),
                            child: SizedBox(
                              width: dw,
                              height: dh,
                              child: Stack(children: [
                                Positioned.fill(
                                    child: Image.memory(p.bytes,
                                        fit: BoxFit.fill, gaplessPlayback: true)),
                                Positioned.fill(
                                    child: CustomPaint(
                                        painter: _CropPainter(crop))),
                              ]),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(children: [
                      for (final (label, v) in <(String, double?)>[
                        (context.tr('crop_free'), null),
                        ('1:1', 1.0),
                        ('4:3', 4 / 3),
                        ('3:4', 3 / 4),
                        ('3:2', 3 / 2),
                        ('16:9', 16 / 9),
                        ('9:16', 9 / 16),
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                              label: Text(label),
                              selected: _aspect == v,
                              onSelected: (_) => _setAspect(v)),
                        ),
                    ]),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton(
                          onPressed: _apply,
                          child: Text(context.tr('crop_apply'))),
                    ),
                  ),
                ]),
    );
  }
}

class _CropPainter extends CustomPainter {
  final Rect crop;
  _CropPainter(this.crop);

  @override
  void paint(Canvas canvas, Size s) {
    final dim = Paint()..color = Colors.black.withValues(alpha: .6);
    canvas.drawRect(Rect.fromLTRB(0, 0, s.width, crop.top), dim);
    canvas.drawRect(Rect.fromLTRB(0, crop.bottom, s.width, s.height), dim);
    canvas.drawRect(Rect.fromLTRB(0, crop.top, crop.left, crop.bottom), dim);
    canvas.drawRect(
        Rect.fromLTRB(crop.right, crop.top, s.width, crop.bottom), dim);

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(crop, border);

    final grid = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = crop.left + crop.width * i / 3;
      final y = crop.top + crop.height * i / 3;
      canvas.drawLine(Offset(x, crop.top), Offset(x, crop.bottom), grid);
      canvas.drawLine(Offset(crop.left, y), Offset(crop.right, y), grid);
    }

    final fill = Paint()..color = const Color(0xFF00E08A);
    for (final c in [
      crop.topLeft,
      crop.topRight,
      crop.bottomLeft,
      crop.bottomRight
    ]) {
      canvas.drawCircle(c, 10, fill);
      canvas.drawCircle(c, 10, border);
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.crop != crop;
}
