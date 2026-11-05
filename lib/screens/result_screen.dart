import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import '../models.dart';
import '../widgets/banner_ad_widget.dart';
import 'compare_screen.dart';

class ResultScreen extends StatelessWidget {
  final List<ProcessResult> results;
  const ResultScreen({super.key, required this.results});

  int get _orig => results.fold(0, (s, r) => s + r.originalBytes);
  int get _now => results.fold(0, (s, r) => s + r.newBytes);

  Future<void> _saveAll(BuildContext context) async {
    final m = ScaffoldMessenger.of(context);
    try {
      var saved = 0;
      for (final r in results) {
        if (!r.isImage) continue;
        await Gal.putImage(r.file.path, album: 'PixelCompress');
        saved++;
      }
      m.showSnackBar(SnackBar(
          content: Text(saved == 0
              ? 'PDFs can\'t go to the gallery - use Share instead'
              : 'Saved $saved photo(s) to the "PixelCompress" album')));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  Future<void> _share(List<ProcessResult> rs) =>
      Share.shareXFiles([for (final r in rs) XFile(r.file.path)]);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final saved = _orig == 0 ? 0.0 : (1 - _now / _orig) * 100;
    return Scaffold(
      appBar: AppBar(title: const Text('Done!')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: cs.surface, borderRadius: BorderRadius.circular(18)),
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(fmtBytes(_orig),
                      style: const TextStyle(
                          fontSize: 20, decoration: TextDecoration.lineThrough)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.arrow_forward_rounded),
                  ),
                  Text(fmtBytes(_now),
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: cs.primary)),
                ],
              ),
              const SizedBox(height: 6),
              Text(saved >= 0
                  ? 'You saved ${saved.toStringAsFixed(0)}% of the space'
                  : 'Result is ${(-saved).toStringAsFixed(0)}% larger (higher quality / lossless format)'),
            ]),
          ),
          const SizedBox(height: 12),
          for (final r in results) _row(context, r, cs),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(children: [
              Expanded(
                  child: FilledButton.icon(
                      onPressed: () => _saveAll(context),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Save'))),
              const SizedBox(width: 12),
              Expanded(
                  child: FilledButton.icon(
                      onPressed: () => _share(results),
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share'))),
            ]),
          ),
          const BannerAdWidget(),
        ]),
      ),
    );
  }

  Widget _row(BuildContext context, ProcessResult r, ColorScheme cs) {
    final pct = r.savedPct;
    final canCompare = r.isImage && r.original != null;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: canCompare
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CompareScreen(
                      before: r.original!,
                      after: r.file,
                      beforeBytes: r.originalBytes,
                      afterBytes: r.newBytes)))
          : null,
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: cs.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 64,
            height: 64,
            child: r.isImage
                ? Image.file(File(r.file.path),
                    fit: BoxFit.cover,
                    cacheWidth: 200,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.image_rounded))
                : const Icon(Icons.picture_as_pdf_rounded, size: 36),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${fmtBytes(r.originalBytes)}  →  ${fmtBytes(r.newBytes)}'
                '  (${pct >= 0 ? '-' : '+'}${pct.abs().toStringAsFixed(0)}%)'),
          ]),
        ),
        if (canCompare) const Icon(Icons.compare_rounded),
        IconButton(
            onPressed: () => _share([r]), icon: const Icon(Icons.share_rounded)),
      ]),
    ));
  }
}
