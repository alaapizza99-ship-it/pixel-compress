import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n.dart';
import '../models.dart';
import '../services/ad_service.dart';
import '../services/image_service.dart';
import '../widgets/banner_ad_widget.dart';
import 'crop_editor_screen.dart';
import 'result_screen.dart';

class ToolScreen extends StatefulWidget {
  final Tool tool;
  const ToolScreen({super.key, required this.tool});

  @override
  State<ToolScreen> createState() => _ToolScreenState();
}

class _ToolScreenState extends State<ToolScreen> {
  final _picker = ImagePicker();
  final _files = <File>[];
  final _sizes = <String, int>{};
  final _o = ProcessOptions();
  final _wCtl = TextEditingController();
  final _hCtl = TextEditingController();
  final _targetCtl = TextEditingController();
  bool _busy = false;
  double _progress = 0;
  bool _byTarget = false; // compress tool: false = by quality, true = target size
  int _targetKb = 200;

  @override
  void initState() {
    super.initState();
    switch (widget.tool) {
      case Tool.compress:
        _o.quality = 60;
        _o.format = OutFormat.jpg;
        break;
      case Tool.resize:
        _o.resize = ResizeKind.dimensions;
        _o.quality = 90;
        break;
      case Tool.crop:
        _o.cropAspect = 1;
        _o.quality = 92;
        break;
      case Tool.blur:
        _o.blurRadius = 10;
        _o.quality = 92;
        break;
      case Tool.convert:
        _o.format = OutFormat.webp;
        _o.quality = 90;
        break;
    }
  }

  @override
  void dispose() {
    _wCtl.dispose();
    _hCtl.dispose();
    _targetCtl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return;
    for (final x in picked) {
      if (_sizes.containsKey(x.path)) continue;
      final f = File(x.path);
      _sizes[x.path] = await f.length();
      _files.add(f);
    }
    if (mounted) setState(() {});
  }

  Future<void> _cropFile(File f) async {
    final r = await Navigator.push<Rect>(
        context,
        MaterialPageRoute(
            builder: (_) => CropEditorScreen(
                file: f,
                aspect: _o.cropAspect,
                initial: _o.cropRects[f.path])));
    if (r != null && mounted) setState(() => _o.cropRects[f.path] = r);
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run() async {
    if (_files.isEmpty) return _snack(context.tr('err_select_first'));

    if (widget.tool == Tool.resize && _o.resize == ResizeKind.dimensions) {
      _o.width = int.tryParse(_wCtl.text);
      _o.height = int.tryParse(_hCtl.text);
      if (_o.width == null && _o.height == null) {
        return _snack(context.tr('err_dims'));
      }
    }

    if (widget.tool == Tool.compress && _byTarget) {
      final kb = int.tryParse(_targetCtl.text) ?? _targetKb;
      if (kb < 10) return _snack(context.tr('err_target'));
      _o.targetKb = kb;
    } else {
      _o.targetKb = null;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      final results = await ImageService.processAll(
          _files, _o, (d, t) => setState(() => _progress = d / t));
      await AdService.maybeShowInterstitial();
      if (!mounted) return;
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ResultScreen(results: results)));
    } catch (e) {
      if (mounted) {
        _snack(_o.format == OutFormat.heic
            ? context.tr('err_heic')
            : context.tr('err_generic', {'e': e}));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr(widget.tool.titleKey))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _photos(cs),
          const SizedBox(height: 16),
          _optionsCard(cs),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _busy
                  ? Column(children: [
                      LinearProgressIndicator(value: _progress),
                      const SizedBox(height: 8),
                      Text(context.tr('processing')),
                    ])
                  : FilledButton.icon(
                      onPressed: _run,
                      icon: Icon(widget.tool.icon),
                      label: Text(_files.isEmpty
                          ? context.tr('start')
                          : context.tr('start_n', {'n': _files.length})),
                    ),
            ),
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }

  Widget _photos(ColorScheme cs) {
    if (_files.isEmpty) {
      return InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _pick,
        child: Container(
          height: 170,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: cs.primary.withValues(alpha: .5), width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_rounded,
                  size: 46, color: cs.primary),
              const SizedBox(height: 8),
              Text(context.tr('select_photos'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(context.tr('n_selected', {'n': _files.length}),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          TextButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.tr('add_more'))),
        ]),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _files.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
          itemBuilder: (_, i) {
            final f = _files[i];
            final hasCrop = _o.cropRects.containsKey(f.path);
            return GestureDetector(
              onTap: widget.tool == Tool.crop ? () => _cropFile(f) : null,
              child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(fit: StackFit.expand, children: [
                Image.file(f,
                    fit: BoxFit.cover,
                    cacheWidth: 300,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.image_not_supported_rounded)),
                if (widget.tool == Tool.crop)
                  Positioned(
                    top: 2,
                    left: 2,
                    child: CircleAvatar(
                        radius: 11,
                        backgroundColor: hasCrop
                            ? Theme.of(context).colorScheme.primary
                            : Colors.black54,
                        child: Icon(Icons.crop_rounded,
                            size: 14,
                            color: hasCrop ? Colors.black : Colors.white)),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(fmtBytes(_sizes[f.path] ?? 0),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.ltr,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _sizes.remove(f.path);
                      _o.cropRects.remove(f.path);
                      _files.removeAt(i);
                    }),
                    child: const CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.black54,
                        child:
                            Icon(Icons.close, size: 14, color: Colors.white)),
                  ),
                ),
              ]),
            ));
          },
        ),
      ],
    );
  }

  Widget _optionsCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cs.surface, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: switch (widget.tool) {
          Tool.compress => _compressOptions(),
          Tool.resize => _resizeOptions(),
          Tool.crop => [
              _label(context.tr('aspect_title')),
              Wrap(spacing: 8, children: [
                _aspectFree(),
                _aspect('1:1', 1),
                _aspect('4:3', 4 / 3),
                _aspect('3:4', 3 / 4),
                _aspect('3:2', 3 / 2),
                _aspect('16:9', 16 / 9),
                _aspect('9:16', 9 / 16),
              ]),
              const SizedBox(height: 8),
              Text(context.tr('crop_hint'),
                  style: const TextStyle(fontSize: 12)),
              _quality(),
            ],
          Tool.blur => [
              _label(context.tr('blur_strength', {'n': _o.blurRadius})),
              Slider(
                  value: _o.blurRadius.toDouble(),
                  min: 1,
                  max: 40,
                  divisions: 39,
                  onChanged: (v) => setState(() => _o.blurRadius = v.round())),
              _quality(),
            ],
          Tool.convert => [
              _label(context.tr('convert_to')),
              _formatChips(const [
                OutFormat.jpg,
                OutFormat.png,
                OutFormat.webp,
                OutFormat.heic,
                OutFormat.pdf
              ]),
              if (_o.format == OutFormat.pdf)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr('merge_pdf')),
                  value: _o.mergePdf,
                  onChanged: (v) => setState(() => _o.mergePdf = v),
                ),
              if (_o.format != OutFormat.png) _quality(),
            ],
        },
      ),
    );
  }

  List<Widget> _compressOptions() => [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
                value: false,
                label: Text(context.tr('mode_quality')),
                icon: const Icon(Icons.tune_rounded)),
            ButtonSegment(
                value: true,
                label: Text(context.tr('mode_target')),
                icon: const Icon(Icons.straighten_rounded)),
          ],
          selected: {_byTarget},
          onSelectionChanged: (s) => setState(() => _byTarget = s.first),
        ),
        if (!_byTarget) ...[
          _label(context.tr('compression_level')),
          Wrap(spacing: 8, children: [
            _preset(context.tr('preset_small'), 30),
            _preset(context.tr('preset_medium'), 60),
            _preset(context.tr('preset_large'), 85),
          ]),
          _quality(),
        ] else ...[
          _label(context.tr('max_size')),
          Wrap(spacing: 8, children: [
            for (final kb in const [50, 100, 200, 500, 1024])
              ChoiceChip(
                label: Text(kb == 1024 ? '1 MB' : '$kb KB'),
                selected: _targetCtl.text.isEmpty && _targetKb == kb,
                onSelected: (_) => setState(() {
                  _targetCtl.clear();
                  _targetKb = kb;
                }),
              ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _targetCtl,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
                labelText: context.tr('target_custom'),
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 6),
          Text(context.tr('target_hint'), style: const TextStyle(fontSize: 12)),
        ],
        _label(context.tr('output_format')),
        _formatChips(const [OutFormat.jpg, OutFormat.webp]),
      ];

  List<Widget> _resizeOptions() => [
        SegmentedButton<ResizeKind>(
          segments: [
            ButtonSegment(
                value: ResizeKind.dimensions,
                label: Text(context.tr('resize_pixels')),
                icon: const Icon(Icons.straighten_rounded)),
            ButtonSegment(
                value: ResizeKind.percent,
                label: Text(context.tr('resize_percent')),
                icon: const Icon(Icons.percent_rounded)),
          ],
          selected: {_o.resize},
          onSelectionChanged: (s) => setState(() => _o.resize = s.first),
        ),
        const SizedBox(height: 12),
        if (_o.resize == ResizeKind.dimensions) ...[
          Row(children: [
            Expanded(child: _num(_wCtl, context.tr('width_px'))),
            const SizedBox(width: 12),
            Expanded(child: _num(_hCtl, context.tr('height_px'))),
          ]),
          const SizedBox(height: 4),
          Text(context.tr('dims_hint'), style: const TextStyle(fontSize: 12)),
          _label(context.tr('fit_title')),
          Wrap(spacing: 8, children: [
            for (final (m, k) in [
              (FitMode.crop, 'fit_crop'),
              (FitMode.stretch, 'fit_stretch'),
              (FitMode.blur, 'fit_blur')
            ])
              ChoiceChip(
                  label: Text(context.tr(k)),
                  selected: _o.fit == m,
                  onSelected: (_) => setState(() => _o.fit = m)),
          ]),
        ] else ...[
          _label(context.tr('scale_pct', {'n': _o.percent.round()})),
          Slider(
              value: _o.percent,
              min: 10,
              max: 100,
              divisions: 90,
              onChanged: (v) => setState(() => _o.percent = v)),
        ],
        _quality(),
      ];

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  Widget _num(TextEditingController c, String hint) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration:
            InputDecoration(labelText: hint, border: const OutlineInputBorder()),
      );

  Widget _quality() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context.tr('quality_n', {'n': _o.quality})),
          Slider(
              value: _o.quality.toDouble(),
              min: 10,
              max: 100,
              divisions: 90,
              onChanged: (v) => setState(() => _o.quality = v.round())),
        ],
      );

  Widget _preset(String n, int q) => ChoiceChip(
      label: Text(n),
      selected: _o.quality == q,
      onSelected: (_) => setState(() => _o.quality = q));

  Widget _aspect(String n, double r) => ChoiceChip(
      label: Text(n),
      selected: _o.cropAspect == r,
      onSelected: (_) => setState(() {
            _o.cropAspect = r;
            _o.cropRects.clear();
          }));

  Widget _aspectFree() => ChoiceChip(
      label: Text(context.tr('crop_free')),
      selected: _o.cropAspect == null,
      onSelected: (_) => setState(() {
            _o.cropAspect = null;
            _o.cropRects.clear();
          }));

  Widget _formatChips(List<OutFormat> fs) => Wrap(spacing: 8, children: [
        for (final f in fs)
          ChoiceChip(
              label: Text(f.label),
              selected: _o.format == f,
              onSelected: (_) => setState(() => _o.format = f)),
      ]);
}
