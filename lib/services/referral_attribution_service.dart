import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/preferences.dart';

/// Captures install / signup attribution for marketing commissions.
///
/// No UI — sources include:
/// - **Google Play** `referrer=` string, e.g.
///   `https://play.google.com/store/apps/details?id=com.hesabu.mauzo&referrer=ref%3D12345`
///   → install referrer payload `ref=12345` (Android only).
/// - `hesabumauzo://invite?ref=AGENTCODE` (custom scheme; Android/iOS).
/// - Web: `?ref=` on first load ([Uri.base]).
///
/// First captured code wins until signup or login clears it.
class ReferralAttributionService {
  ReferralAttributionService._();

  static const String _prefsKey = 'pending_install_referrer_code_v1';

  /// Uppercase A–Z, 0–9, underscore, hyphen; length 2–40.
  static String? normalizeReferrerCode(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.length < 2 || t.length > 40) return null;
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(t)) return null;
    return t.toUpperCase();
  }

  static String? _extractFromUri(Uri uri) {
    for (final key in ['ref', 'referrer', 'r', 'invite']) {
      final v = uri.queryParameters[key];
      final n = normalizeReferrerCode(v);
      if (n != null) return n;
    }
    return null;
  }

  /// Play Install Referrer returns a string like `ref=CODE` or UTM pairs (decoded).
  static String? _extractFromPlayReferrerString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final trimmed = raw.trim();
    try {
      final map = Uri.splitQueryString(trimmed);
      for (final key in ['ref', 'referrer', 'r', 'invite', 'utm_content', 'utm_campaign']) {
        final v = map[key];
        final n = normalizeReferrerCode(v);
        if (n != null) return n;
      }
    } catch (_) {
      // ignore malformed query-style strings
    }
    return normalizeReferrerCode(trimmed);
  }

  static Future<void> _storePendingIfAllowed(String normalizedCode) async {
    try {
      if (Preferences.isLoggedIn()) return;
    } catch (_) {
      // Preferences not ready — still allow capture for cold start
    }
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefsKey);
    if (existing != null && existing.isNotEmpty) return;
    await prefs.setString(_prefsKey, normalizedCode);
    debugPrint('ReferralAttributionService: stored pending code (silent)');
  }

  /// Save code from a deep link or landing URL if user is not logged in yet.
  static Future<void> ingestUri(Uri? uri) async {
    if (uri == null) return;
    final code = _extractFromUri(uri);
    if (code == null) return;
    await _storePendingIfAllowed(code);
  }

  /// Google Play Install Referrer API (Android). Safe no-op elsewhere / on error.
  static Future<void> ingestPlayInstallReferrerPayload(String? installReferrer) async {
    final code = _extractFromPlayReferrerString(installReferrer);
    if (code == null) return;
    await _storePendingIfAllowed(code);
  }

  static Future<String?> getPendingCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey);
  }

  static Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  static Future<void> _tryAndroidPlayInstallReferrer() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final details = await PlayInstallReferrer.installReferrer;
      await ingestPlayInstallReferrerPayload(details.installReferrer);
    } catch (e, st) {
      debugPrint('ReferralAttributionService Play Install Referrer: $e\n$st');
    }
  }

  /// Call after [Preferences.init] during app startup.
  static Future<void> bootstrap() async {
    if (kIsWeb) {
      await ingestUri(Uri.base);
      return;
    }
    try {
      final appLinks = AppLinks();
      final initial = await appLinks.getInitialLink();
      if (initial != null) await ingestUri(initial);
      appLinks.uriLinkStream.listen(ingestUri);
    } catch (e, st) {
      debugPrint('ReferralAttributionService.bootstrap app_links: $e\n$st');
    }

    // Store install: Play `referrer=` only fills pending if still empty (deep link wins first).
    final pending = await getPendingCode();
    if (pending == null || pending.isEmpty) {
      await _tryAndroidPlayInstallReferrer();
    }
  }
}
