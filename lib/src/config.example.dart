// Template — copy this to config.dart and set your local values.
// config.dart is gitignored so it never gets committed.
//
//   cp lib/src/config.example.dart lib/src/config.dart

// Local development uses --dart-define instead of a constant here, so nothing
// in the source has to change to point at a dev server:
//
//   ./run_local.sh            http://localhost:3011   (Chrome / macOS)
//   ./run_local.sh --emulator http://10.0.2.2:3011    (Android emulator)
//   ./run_local.sh --device   http://<your-LAN-IP>:3011
//
// Port comes from backend/.env (PORT=3011).
const String _prodApiUrl = 'https://api.flettra.com';

/// Production by default, in debug as well as release.
///
/// Previously debug builds pointed at localhost, which is right while building a
/// feature and wrong once you are testing real behaviour on a device or handing
/// a build to someone. Local work now opts in rather than being the default:
///
///   ./run_local.sh              -> --dart-define=API_URL=http://localhost:3011
///   flutter run                 -> https://api.flettra.com
///   flutter build ipa/appbundle -> https://api.flettra.com
const String apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: _prodApiUrl,
);

/// Same key as MAPS_API_KEY in AndroidManifest.xml.
const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
