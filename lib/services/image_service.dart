import 'dart:io';
import 'dart:typed_data';
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
  if (ca != null) {
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

  // Lossless intermediate only when the result is PNG; otherwise high-quality JPEG.
  return a['png'] as bool
      ? Uint8List.fromList(img.encodePng(image, level: 1))
      : Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

class ImageService {
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
    if (!o.needsPixelOps) {
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
      'resize': o.resize.index,
      'fit': o.fit.index,
      'percent': o.percent,
      'w': o.width,
      'h': o.height,
      'blur': o.blurRadius,
      'png': fmt == OutFormat.png,
    });
    return FlutterImageCompress.compressWithList(edited,
        quality: o.quality, format: cf, minWidth: 10000, minHeight: 10000);
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
      final bytes = await _encode(files[i], o, fmt);
      final out = File('${dir.path}/pixelcompress_${stamp}_$i.${fmt.ext}');
      await out.writeAsBytes(bytes);
      results.add(ProcessResult(out, 'Photo ${i + 1}.${fmt.ext}',
          await files[i].length(), bytes.length,
          original: files[i]));
      onProgress(i + 1, files.length);
    }
    return results;
  }
}
