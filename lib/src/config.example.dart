import 'package:flutter/foundation.dart';

// Template — copy this to config.dart and set your local values.
// config.dart is gitignored so it never gets committed.
//
//   cp lib/src/config.example.dart lib/src/config.dart
//
// The API host resolves in this order:
//   1. --dart-define=API_URL=...   (explicit override; used by run_local.sh)
//   2. debug builds   -> local backend
//   3. release builds -> production
//
// Release builds default to production, so a packaged build cannot ship
// pointing at a local server.

/// Local backend. Port comes from backend/.env (PORT=3011).
/// Android emulator: http://10.0.2.2:3011 — physical device: your LAN IP.
const String _localApiUrl = 'http://localhost:3011';

const String _prodApiUrl = 'https://api.flettra.com';

const String apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: kReleaseMode ? _prodApiUrl : _localApiUrl,
);

/// Same key as MAPS_API_KEY in AndroidManifest.xml.
const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
