import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the offline-font setup.
///
/// `main.dart` sets `GoogleFonts.config.allowRuntimeFetching = false` so the app
/// never waits on fonts.gstatic.com before it can paint. The package then
/// resolves DM Sans from the asset bundle instead — but only if it finds an
/// asset whose name, without extension, ends in exactly `DM Sans-<Weight>`.
///
/// That naming is not obvious (note the space, and that w400 maps to `Regular`
/// rather than `400`), and getting it wrong fails silently: google_fonts logs
/// and falls back to the platform font, so the app renders in the wrong
/// typeface with no crash to notice. Hence this test.
///
/// If it fails, check `google_fonts/` and the `assets:` entry in pubspec.yaml.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Weight -> google_fonts filename part, for every weight the app requests.
  /// Sourced from `_fontWeightToFilenameWeightParts` in the package.
  const weightParts = <int, String>{
    400: 'Regular',
    500: 'Medium',
    600: 'SemiBold',
    700: 'Bold',
    800: 'ExtraBold',
  };

  test('DM Sans is bundled for every weight the app uses', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();

    for (final entry in weightParts.entries) {
      final expectedSuffix = 'DM Sans-${entry.value}';
      final matched = assets.any((asset) {
        for (final ext in const ['.ttf', '.otf']) {
          if (asset.endsWith(ext)) {
            return asset
                .substring(0, asset.length - ext.length)
                .endsWith(expectedSuffix);
          }
        }
        return false;
      });

      expect(
        matched,
        isTrue,
        reason: 'No bundled font asset ends in "$expectedSuffix". '
            'google_fonts will silently fall back to the platform font for '
            'FontWeight.w${entry.key}, which the app uses.',
      );
    }
  });

  test('the DMSans family used by AppTheme is declared', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();

    for (final weight in const ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      expect(
        assets.contains('assets/fonts/DMSans-$weight.ttf'),
        isTrue,
        reason: 'assets/fonts/DMSans-$weight.ttf is missing; AppTheme sets '
            'fontFamily: "DMSans" and would fall back to the platform font.',
      );
    }
  });
}
