import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models.dart';

/// Runs in a background isolate: crop / resize / blur on decoded pixels.
Uint8List _pixelOps(Map<String, dynamic> a) {
  var image = img.decodeImage(a['bytes'] as Uint8List);
  if (image == null) throw Exception('Unsupported image format');
  image = img.bakeOrientation(image);

  // 1) crop to aspect ratio (center crop)
  final ca = a['cropAspect'] as double?;
  final cr = (a['cropRect'] as List?)?.cast<double>(); // l, t, r, b as fractions
  if (cr != null) {
    final x = (cr[0] * image.width).round().clamp(0, image.width - 1);
    final y = (cr[1] * image.height).round().clamp(0, image.height - 1);
    final w = ((cr[2] - cr[0]) * image.width).round().clamp(1, image.width - x);
    final h = ((cr[3] - cr[1]) * image.height).round().clamp(1, image.height - y);
    image = img.copyCrop(image, x: x, y: y, width: w, height: h);
  } else if (ca != null) {
    final cur = image.width / image.height;
    var w = image.width, h = image.height;
    if (cur > ca) {
      w = (image.height * ca).round();
    } else {
      h = (image.width / ca).round();
    }
    image = img.copyCrop(image,
        x: (image.width - w) ~/ 2,
        y: (image.height - h) ~/ 2,
        width: w,
        height: h);
  }

  // 2) resize
  final kind = a['resize'] as int; // 0 none, 1 dimensions, 2 percent
  int? tw, th;
  var fit = FitMode.values[a['fit'] as int];
  if (kind == 2) {
    final p = (a['percent'] as double) / 100;
    tw = (image.width * p).round().clamp(1, 20000);
    th = (image.height * p).round().clamp(1, 20000);
    fit = FitMode.stretch;
  } else if (kind == 1) {
    tw = a['w'] as int?;
    th = a['h'] as int?;
  }
  if (tw != null && th != null) {
    final coverScale = (tw / image.width) > (th / image.height)
        ? tw / image.width
        : th / image.height;
    switch (fit) {
      case FitMode.stretch:
        image = img.copyResize(image,
            width: tw, height: th, interpolation: img.Interpolation.linear);
        break;
      case FitMode.crop:
        final rw = (image.width * coverScale).ceil();
        final rh = (image.height * coverScale).ceil();
        final big = img.copyResize(image,
            width: rw, height: rh, interpolation: img.Interpolation.linear);
        image = img.copyCrop(big,
            x: (rw - tw) ~/ 2, y: (rh - th) ~/ 2, width: tw, height: th);
        break;
      case FitMode.blur:
        final fitScale = (tw / image.width) < (th / image.height)
            ? tw / image.width
            : th / image.height;
        final fw = (image.width * fitScale).round().clamp(1, tw);
        final fh = (image.height * fitScale).round().clamp(1, th);
        final fg = img.copyResize(image,
            width: fw, height: fh, interpolation: img.Interpolation.linear);
        final cw = (image.width * coverScale).ceil();
        final ch = (image.height * coverScale).ceil();
        var bg = img.copyResize(image,
            width: cw, height: ch, interpolation: img.Interpolation.average);
        bg = img.copyCrop(bg,
            x: (cw - tw) ~/ 2, y: (ch - th) ~/ 2, width: tw, height: th);
        bg = img.gaussianBlur(bg, radius: 25);
        image = img.compositeImage(bg, fg,
            dstX: (tw - fw) ~/ 2, dstY: (th - fh) ~/ 2);
        break;
    }
  } else if (tw != null || th != null) {
    image = img.copyResize(image,
        width: tw, height: th, interpolation: img.Interpolation.linear);
  }

  // 3) blur
  final blur = a['blur'] as int;
  if (blur > 0) image = img.gaussianBlur(image, radius: blur);

  if (a['png'] as bool) {
    // PNG is lossless, so "quality" here means the number of colours:
    // 0 = keep every colour (lossless), otherwise reduce to that many colours.
    final colors = a['pngColors'] as int;
    var out = image;
    if (colors > 0) {
      out = img.quantize(image,
          numberOfColors: colors,
          quantizerType: img.QuantizerType.octree,
          dither: img.DitherKernel.floydSteinberg);
    }
    return Uint8List.fromList(img.encodePng(out, level: 9));
  }
  // Otherwise a high-quality JPEG intermediate, finished by the native encoder.
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

/// A downscaled, orientation-corrected copy of a photo for the crop editor.
/// It goes through the same decode + bakeOrientation as the real processing,
/// so a frame drawn on it lands on exactly the same pixels in the final photo.
class CropPreview {
  final Uint8List bytes;
  final int width;
  final int height;
  CropPreview(this.bytes, this.width, this.height);
}

Map<String, dynamic> _previewOps(Uint8List bytes) {
  var image = img.decodeImage(bytes);
  if (image == null) throw Exception('Unsupported image format');
  image = img.bakeOrientation(image);
  if (image.width > 1600 || image.height > 1600) {
    image = image.width >= image.height
        ? img.copyResize(image, width: 1600)
        : img.copyResize(image, height: 1600);
  }
  return {
    'bytes': Uint8List.fromList(img.encodeJpg(image, quality: 85)),
    'w': image.width,
    'h': image.height,
  };
}

class ImageService {
  static Future<CropPreview> prepareCropPreview(File f) async {
    var bytes = await f.readAsBytes();
    final e = _ext(f);
    if (e == 'heic' || e == 'heif') {
      final j = await FlutterImageCompress.compressWithFile(f.path,
          quality: 100,
          format: CompressFormat.jpeg,
          minWidth: 10000,
          minHeight: 10000);
      if (j != null) bytes = j;
    }
    final r = await compute(_previewOps, bytes);
    return CropPreview(r['bytes'] as Uint8List, r['w'] as int, r['h'] as int);
  }

  static CompressFormat _cf(OutFormat f) => switch (f) {
        OutFormat.png => CompressFormat.png,
        OutFormat.webp => CompressFormat.webp,
        OutFormat.heic => CompressFormat.heic,
        _ => CompressFormat.jpeg,
      };

  static String _ext(File f) => f.path.split('.').last.toLowerCase();

  static OutFormat _resolve(OutFormat want, File f) {
    if (want != OutFormat.keep) return want;
    final e = _ext(f);
    if (e == 'png') return OutFormat.png;
    if (e == 'webp') return OutFormat.webp;
    return OutFormat.jpg;
  }

  static Future<Uint8List> _encode(
      File f, ProcessOptions o, OutFormat fmt) async {
    final cf = _cf(fmt);
    final isPng = fmt == OutFormat.png;
    // PNG always goes through the Dart encoder so its quality slider really works
    // (the native PNG encoder ignores quality).
    final px = o.needsPixelFor(f) || (isPng && o.targetKb == null);
    if (o.targetKb != null && !o.needsPixelFor(f)) {
      return _encodeToTarget(f, o.targetKb! * 1024, cf);
    }
    if (!px) {
      final out = await FlutterImageCompress.compressWithFile(f.path,
          quality: o.quality,
          format: cf,
          minWidth: 10000,
          minHeight: 10000,
          keepExif: false);
      if (out == null) throw Exception('Could not process this image');
      return out;
    }
    var bytes = await f.readAsBytes();
    final e = _ext(f);
    if (e == 'heic' || e == 'heif') {
      final j = await FlutterImageCompress.compressWithFile(f.path,
          quality: 100,
          format: CompressFormat.jpeg,
          minWidth: 10000,
          minHeight: 10000);
      if (j != null) bytes = j;
    }
    final edited = await compute(_pixelOps, <String, dynamic>{
      'bytes': bytes,
      'cropAspect': o.cropAspect,
      'cropRect': o.cropRects[f.path] == null
          ? null
          : [
              o.cropRects[f.path]!.left,
              o.cropRects[f.path]!.top,
              o.cropRects[f.path]!.right,
              o.cropRects[f.path]!.bottom,
            ],
      'resize': o.resize.index,
      'fit': o.fit.index,
      'percent': o.percent,
      'w': o.width,
      'h': o.height,
      'blur': o.blurRadius,
      'png': isPng,
      'pngColors':
          o.quality >= 90 ? 0 : (o.quality * 256 / 100).round().clamp(16, 256),
    });
    if (isPng) return edited; // already the final PNG
    return FlutterImageCompress.compressWithList(edited,
        quality: o.quality, format: cf, minWidth: 10000, minHeight: 10000);
  }

  /// Finds the highest quality whose output fits in [target] bytes.
  /// If even the lowest quality is too big, the photo is scaled down step by step.
  static Future<Uint8List> _encodeToTarget(
      File f, int target, CompressFormat cf) async {
    var w = 4000, h = 4000;
    try {
      final raw = await f.readAsBytes();
      final buf = await ui.ImmutableBuffer.fromUint8List(raw);
      final desc = await ui.ImageDescriptor.encoded(buf);
      w = desc.width;
      h = desc.height;
      desc.dispose();
      buf.dispose();
    } catch (_) {}
    final shortSide = w < h ? w : h;

    Future<Uint8List> enc(int q, double s) async {
      // Both minimums equal the short side * s, so the scale is the same
      // whatever the photo's rotation.
      final m = (shortSide * s).round().clamp(1, 100000);
      final out = await FlutterImageCompress.compressWithFile(f.path,
          quality: q,
          format: cf,
          minWidth: m,
          minHeight: m,
          keepExif: false);
      if (out == null) throw Exception('Could not process this image');
      return out;
    }

    const minQ = 30;
    var scale = 1.0;
    var last = Uint8List(0);
    for (var attempt = 0; attempt < 8; attempt++) {
      last = await enc(minQ, scale);
      if (last.length <= target) {
        var best = last;
        var lo = minQ + 1, hi = 95;
        while (lo <= hi) {
          final mid = (lo + hi) ~/ 2;
          final out = await enc(mid, scale);
          if (out.length <= target) {
            best = out;
            lo = mid + 1;
          } else {
            hi = mid - 1;
          }
        }
        return best;
      }
      scale *= 0.8;
    }
    return last;
  }

  /// Re-encodes at progressively lower quality until the result is smaller than
  /// [originalSize]. Returns null when no quality gets below the original.
  static Future<Uint8List?> _encodeSmaller(
      File f, ProcessOptions o, OutFormat fmt, int originalSize) async {
    for (final step in const [0.75, 0.55, 0.4, 0.3]) {
      final q = (o.quality * step).round().clamp(15, 100);
      final out = await FlutterImageCompress.compressWithFile(f.path,
          quality: q,
          format: _cf(fmt),
          minWidth: 10000,
          minHeight: 10000,
          keepExif: false);
      if (out != null && out.length < originalSize) return out;
    }
    return null;
  }

  static Future<Uint8List> _pdf(List<Uint8List> jpgs) async {
    final doc = pw.Document();
    for (final b in jpgs) {
      final mem = pw.MemoryImage(b);
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Center(child: pw.Image(mem, fit: pw.BoxFit.contain)),
      ));
    }
    return Uint8List.fromList(await doc.save());
  }

  static Future<List<ProcessResult>> processAll(List<File> files,
      ProcessOptions o, void Function(int done, int total) onProgress) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;

    if (o.format == OutFormat.pdf) {
      final pages = <Uint8List>[];
      final perFile = <ProcessResult>[];
      var orig = 0;
      for (var i = 0; i < files.length; i++) {
        final size = await files[i].length();
        orig += size;
        final jpg = await _encode(files[i], o, OutFormat.jpg);
        if (o.mergePdf) {
          pages.add(jpg);
        } else {
          final out = File('${dir.path}/pixelcompress_${stamp}_$i.pdf');
          await out.writeAsBytes(await _pdf([jpg]));
          perFile.add(ProcessResult(out, 'PDF ${i + 1}', size, await out.length(),
              isImage: false));
        }
        onProgress(i + 1, files.length);
      }
      if (!o.mergePdf) return perFile;
      final out = File('${dir.path}/pixelcompress_$stamp.pdf');
      await out.writeAsBytes(await _pdf(pages));
      return [
        ProcessResult(out, 'PDF (${files.length} pages)', orig, await out.length(),
            isImage: false)
      ];
    }

    final results = <ProcessResult>[];
    for (var i = 0; i < files.length; i++) {
      final fmt = _resolve(o.format, files[i]);
      final size = await files[i].length();
      var bytes = await _encode(files[i], o, fmt);

      // Compressing must never make a photo bigger. Try lower qualities; if the
      // photo is already as small as it gets, keep the original untouched.
      if (o.ensureSmaller && fmt != OutFormat.png && bytes.length >= size) {
        final smaller = await _encodeSmaller(files[i], o, fmt, size);
        if (smaller == null) {
          final ext = _ext(files[i]);
          final kept = File('${dir.path}/pixelcompress_${stamp}_$i.$ext');
          await files[i].copy(kept.path);
          results.add(ProcessResult(kept, 'Photo ${i + 1}.$ext', size, size,
              original: files[i], alreadyCompressed: true));
          onProgress(i + 1, files.length);
          continue;
        }
        bytes = smaller;
      }

      final out = File('${dir.path}/pixelcompress_${stamp}_$i.${fmt.ext}');
      await out.writeAsBytes(bytes);
      results.add(ProcessResult(out, 'Photo ${i + 1}.${fmt.ext}', size, bytes.length,
          original: files[i]));
      onProgress(i + 1, files.length);
    }
    return results;
  }
}
