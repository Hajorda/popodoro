import 'dart:io';

import 'package:flutter/services.dart';

/// Dart wrapper around the native security-scoped bookmark channel.
///
/// On macOS, `user-selected.read-write` access lasts only for the file-picker
/// session. This service persists opaque bookmark data (base64) so the app can
/// restore sandbox access across relaunches without asking the user again.
///
/// All methods are no-ops on non-macOS platforms and return null / do nothing.
class BookmarkService {
  static const _ch = MethodChannel('popodoro/bookmarks');

  static bool get isSupported => Platform.isMacOS;

  /// Creates a security-scoped bookmark for [path] (typically right after the
  /// user picks the folder). Returns base64-encoded bookmark data to persist,
  /// or null on failure.
  static Future<String?> createBookmark(String path) async {
    if (!isSupported) return null;
    try {
      return await _ch.invokeMethod<String>('createBookmark', path);
    } on PlatformException {
      return null;
    }
  }

  /// Resolves a previously saved bookmark and calls
  /// `startAccessingSecurityScopedResource`. Returns the resolved path (may
  /// differ from the original if the folder was moved), or null on failure.
  ///
  /// Returns `{'path': String, 'stale': bool}` or null on failure.
  /// When stale is true the bookmark must be recreated — call [createBookmark]
  /// on the returned path while access is still active.
  static Future<BookmarkResult?> resolveBookmark(String base64) async {
    if (!isSupported) return null;
    try {
      final raw = await _ch.invokeMapMethod<String, dynamic>('resolveBookmark', base64);
      if (raw == null) return null;
      return BookmarkResult(
        path: raw['path'] as String,
        stale: raw['stale'] as bool,
      );
    } on PlatformException {
      return null;
    }
  }

  /// Calls `stopAccessingSecurityScopedResource` for [path]. Must be called
  /// when the app no longer needs access (disconnect or terminate).
  static Future<void> stopAccessing(String path) async {
    if (!isSupported) return;
    try {
      await _ch.invokeMethod<void>('stopAccessing', path);
    } on PlatformException {
      // ignore — resource may have already been stopped
    }
  }
}

class BookmarkResult {
  const BookmarkResult({required this.path, required this.stale});
  final String path;
  final bool stale;
}
