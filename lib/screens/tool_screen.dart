import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models.dart';
import '../services/ad_service.dart';
import '../services/image_service.dart';
import '../widgets/banner_ad_widget.dart';
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
  bool _busy = false;
  double _progress = 0;

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

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run() async {
    if (_files.isEmpty) return _snack('Select at least one photo first');
    if (widget.tool == Tool.resize && _o.resize == ResizeKind.dimensions) {
      _o.width = int.tryParse(_wCtl.text);
      _o.height = int.tryParse(_hCtl.text);
      if (_o.width == null && _o.height == null) {
        return _snack('Enter a width, a height, or both');
      }
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
      _snack(_o.format == OutFormat.heic
          ? 'HEIC output needs Android 11 or newer. Try WEBP or JPG.'
          : 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.tool.title)),
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
                      const Text('Processing…'),
                    ])
                  : FilledButton.icon(
                      onPressed: _run,
                      icon: Icon(widget.tool.icon),
                      label: Text(_files.isEmpty
                          ? 'Start'
                          : 'Start (${_files.length} photo${_files.length > 1 ? 's' : ''})'),
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
            border: Border.all(color: cs.primary.withValues(alpha: .5), width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_rounded, size: 46, color: cs.primary),
              const SizedBox(height: 8),
              const Text('Select photos (multiple allowed)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('${_files.length} selected',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          TextButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add more')),
        ]),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _files.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
          itemBuilder: (_, i) {
            final f = _files[i];
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(fit: StackFit.expand, children: [
                Image.file(f,
                    fit: BoxFit.cover,
                    cacheWidth: 300,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.image_not_supported_rounded)),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(fmtBytes(_sizes[f.path] ?? 0),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _sizes.remove(f.path);
                      _files.removeAt(i);
                    }),
                    child: const CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 14, color: Colors.white)),
                  ),
                ),
              ]),
            );
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
          Tool.compress => [
              _label('Compression level'),
              Wrap(spacing: 8, children: [
                _preset('Small file', 30),
                _preset('Medium', 60),
                _preset('Large file', 85),
              ]),
              _quality(),
              _label('Output format'),
              _formatChips(const [OutFormat.jpg, OutFormat.webp]),
            ],
          Tool.resize => _resizeOptions(),
          Tool.crop => [
              _label('Aspect ratio (center crop)'),
              Wrap(spacing: 8, children: [
                _aspect('1:1', 1),
                _aspect('4:3', 4 / 3),
                _aspect('3:4', 3 / 4),
                _aspect('3:2', 3 / 2),
                _aspect('16:9', 16 / 9),
                _aspect('9:16', 9 / 16),
              ]),
              _quality(),
            ],
          Tool.blur => [
              _label('Blur strength: ${_o.blurRadius}'),
              Slider(
                  value: _o.blurRadius.toDouble(),
                  min: 1,
                  max: 40,
                  divisions: 39,
                  onChanged: (v) => setState(() => _o.blurRadius = v.round())),
              _quality(),
            ],
          Tool.convert => [
              _label('Convert to'),
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
                  title: const Text('Merge all photos into one PDF'),
                  value: _o.mergePdf,
                  onChanged: (v) => setState(() => _o.mergePdf = v),
                ),
              if (_o.format != OutFormat.png) _quality(),
            ],
        },
      ),
    );
  }

  List<Widget> _resizeOptions() => [
        SegmentedButton<ResizeKind>(
          segments: const [
            ButtonSegment(
                value: ResizeKind.dimensions,
                label: Text('Pixels'),
                icon: Icon(Icons.straighten_rounded)),
            ButtonSegment(
                value: ResizeKind.percent,
                label: Text('Percent'),
                icon: Icon(Icons.percent_rounded)),
          ],
          selected: {_o.resize},
          onSelectionChanged: (s) => setState(() => _o.resize = s.first),
        ),
        const SizedBox(height: 12),
        if (_o.resize == ResizeKind.dimensions) ...[
          Row(children: [
            Expanded(child: _num(_wCtl, 'Width (px)')),
            const SizedBox(width: 12),
            Expanded(child: _num(_hCtl, 'Height (px)')),
          ]),
          const SizedBox(height: 4),
          const Text('Fill only one box to keep the original proportions.',
              style: TextStyle(fontSize: 12)),
          _label('If both are set and the shape differs'),
          Wrap(spacing: 8, children: [
            for (final (m, n) in [
              (FitMode.crop, 'Crop'),
              (FitMode.stretch, 'Stretch'),
              (FitMode.blur, 'Fit + blur')
            ])
              ChoiceChip(
                  label: Text(n),
                  selected: _o.fit == m,
                  onSelected: (_) => setState(() => _o.fit = m)),
          ]),
        ] else ...[
          _label('Scale: ${_o.percent.round()}%'),
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
        decoration: InputDecoration(
            labelText: hint, border: const OutlineInputBorder()),
      );

  Widget _quality() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Quality: ${_o.quality}%'),
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
      onSelected: (_) => setState(() => _o.cropAspect = r));

  Widget _formatChips(List<OutFormat> fs) => Wrap(spacing: 8, children: [
        for (final f in fs)
          ChoiceChip(
              label: Text(f.label),
              selected: _o.format == f,
              onSelected: (_) => setState(() => _o.format = f)),
      ]);
}
