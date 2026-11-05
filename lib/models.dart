import 'dart:io';
import 'package:flutter/material.dart';

enum Tool { compress, resize, crop, blur, convert }

extension ToolInfo on Tool {
  String get title => switch (this) {
        Tool.compress => 'Compress Photo',
        Tool.resize => 'Resize Photo',
        Tool.crop => 'Crop Photo',
        Tool.blur => 'Blur Photo',
        Tool.convert => 'Convert Photo',
      };
  String get subtitle => switch (this) {
        Tool.compress => 'Shrink file size, keep quality',
        Tool.resize => 'By pixels or percentage',
        Tool.crop => 'Square, 4:3, 16:9 and more',
        Tool.blur => 'Soften or hide details',
        Tool.convert => 'JPG, PNG, WEBP, HEIC, PDF',
      };
  IconData get icon => switch (this) {
        Tool.compress => Icons.compress_rounded,
        Tool.resize => Icons.aspect_ratio_rounded,
        Tool.crop => Icons.crop_rounded,
        Tool.blur => Icons.blur_on_rounded,
        Tool.convert => Icons.swap_horiz_rounded,
      };
}

enum OutFormat { keep, jpg, png, webp, heic, pdf }

extension OutFormatX on OutFormat {
  String get label => name.toUpperCase();
  String get ext => name;
}

enum ResizeKind { none, dimensions, percent }

/// How to fill a target size when both width and height are given.
enum FitMode { crop, stretch, blur }

class ProcessOptions {
  int quality = 80;
  OutFormat format = OutFormat.keep;
  ResizeKind resize = ResizeKind.none;
  int? width;
  int? height;
  double percent = 50;
  FitMode fit = FitMode.blur;
  double? cropAspect; // width / height
  int blurRadius = 0;
  bool mergePdf = true;

  bool get needsPixelOps =>
      resize != ResizeKind.none || cropAspect != null || blurRadius > 0;
}

class ProcessResult {
  final File file;
  final String label;
  final int originalBytes;
  final int newBytes;
  final bool isImage;
  final File? original;
  ProcessResult(this.file, this.label, this.originalBytes, this.newBytes,
      {this.isImage = true, this.original});

  double get savedPct =>
      originalBytes == 0 ? 0 : (1 - newBytes / originalBytes) * 100;
}

String fmtBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  return '${(b / 1024 / 1024).toStringAsFixed(2)} MB';
}
