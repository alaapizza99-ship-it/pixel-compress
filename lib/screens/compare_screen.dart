import 'dart:io';
import 'package:flutter/material.dart';
import '../models.dart';

class _LeftClipper extends CustomClipper<Rect> {
  final double f;
  _LeftClipper(this.f);
  @override
  Rect getClip(Size s) => Rect.fromLTWH(0, 0, s.width * f, s.height);
  @override
  bool shouldReclip(_LeftClipper o) => o.f != f;
}

class CompareScreen extends StatefulWidget {
  final File before;
  final File after;
  final int beforeBytes;
  final int afterBytes;
  const CompareScreen({
    super.key,
    required this.before,
    required this.after,
    required this.beforeBytes,
    required this.afterBytes,
  });

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  double _pos = .5;

  Widget _chip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: Colors.black54, borderRadius: BorderRadius.circular(20)),
        child: Text(t,
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      );

  Widget _img(File f) => Image.file(f,
      fit: BoxFit.contain,
      cacheWidth: 1600,
      errorBuilder: (_, __, ___) =>
          const Center(child: Icon(Icons.image_not_supported_rounded)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Before / After')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(builder: (_, box) {
                final w = box.maxWidth, h = box.maxHeight;
                return GestureDetector(
                  onHorizontalDragUpdate: (d) => setState(
                      () => _pos = (_pos + d.delta.dx / w).clamp(0.0, 1.0)),
                  onTapDown: (d) => setState(
                      () => _pos = (d.localPosition.dx / w).clamp(0.0, 1.0)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(children: [
                      Positioned.fill(child: _img(widget.after)),
                      Positioned.fill(
                        child: ClipRect(
                            clipper: _LeftClipper(_pos),
                            child: _img(widget.before)),
                      ),
                      Positioned(
                          left: w * _pos - 1.5,
                          top: 0,
                          bottom: 0,
                          child: Container(width: 3, color: Colors.white)),
                      Positioned(
                        left: w * _pos - 18,
                        top: h / 2 - 18,
                        child: const CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.swap_horiz_rounded,
                              color: Colors.black87),
                        ),
                      ),
                      Positioned(
                          left: 10,
                          top: 10,
                          child: _chip(
                              'Before · ${fmtBytes(widget.beforeBytes)}')),
                      Positioned(
                          right: 10,
                          top: 10,
                          child:
                              _chip('After · ${fmtBytes(widget.afterBytes)}')),
                    ]),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            const Text('Drag the handle to compare'),
          ],
        ),
      ),
    );
  }
}
