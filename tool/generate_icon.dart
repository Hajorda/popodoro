// Run with: flutter run -d macos --target tool/generate_icon.dart
// Renders the Pop mascot at 1024×1024 and saves it to assets/icon/icon.png, then exits.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:popodoro/widgets/mascot/pop_mascot.dart';

void main() {
  runApp(const _IconGeneratorApp());
}

class _IconGeneratorApp extends StatelessWidget {
  const _IconGeneratorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _IconCapturePage(),
    );
  }
}

class _IconCapturePage extends StatefulWidget {
  @override
  State<_IconCapturePage> createState() => _IconCapturePageState();
}

class _IconCapturePageState extends State<_IconCapturePage> {
  final GlobalKey _key = GlobalKey();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // Wait two frames so the widget is fully laid out and painted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
    });
  }

  Future<void> _capture() async {
    if (_done) return;
    _done = true;

    final boundary =
        _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    // pixelRatio 1.0 — the widget is already 1024×1024 logical px.
    final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final outFile = File('assets/icon/icon.png');
    await outFile.writeAsBytes(bytes);

    debugPrint('✓ Saved ${bytes.length ~/ 1024} KB → ${outFile.path}');
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F2), // app bg (cream)
      body: Center(
        child: RepaintBoundary(
          key: _key,
          child: Container(
            width: 1024,
            height: 1024,
            color: const Color(0xFFFBF8F2),
            child: Center(
              child: PopMascot(
                size: 820, // fill most of the canvas, leaving breathing room
                mood: PopMood.hi,
                accentColor: const Color(0xFFFFC857),
                bumpColor: const Color(0xFFFFF6E1),
                bumpEdgeColor: const Color(0xFFF2E6C6),
                inkColor: const Color(0xFF1C1A17),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
