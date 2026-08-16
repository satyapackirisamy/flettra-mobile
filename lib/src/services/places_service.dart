import 'package:dio/dio.dart';
import '../config.dart';

class PlacePrediction {
  final String description;
  final String placeId;
  final String mainText; // city / locality name (before the first comma)

  const PlacePrediction({
    required this.description,
    required this.placeId,
    required this.mainText,
  });
}

class PlacesService {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
  ));

  /// Returns city/place autocomplete predictions restricted to India.
  static Future<List<PlacePrediction>> autocomplete(String input) async {
    if (input.trim().length < 2) return [];
    try {
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: {
          'input': input.trim(),
          'types': '(cities)',
          'components': 'country:in',
          'language': 'en',
          'key': googleMapsApiKey,
        },
      );
      if (res.statusCode == 200 && res.data['status'] == 'OK') {
        final List predictions = res.data['predictions'];
        final query = input.trim().toLowerCase();
        return predictions
            .map((p) {
              final description = p['description'] as String;
              final mainText = (p['structured_formatting']?['main_text'] as String?) ??
                  description.split(',').first.trim();
              return PlacePrediction(
                description: description,
                placeId: p['place_id'] as String,
                mainText: mainText,
              );
            })
            // Only keep cities whose name STARTS WITH what the user typed.
            // Google's API can match "Ch" anywhere in a name (e.g. "Trichy"),
            // so we filter client-side to enforce a prefix match.
            .where((p) => p.mainText.toLowerCase().startsWith(query))
            .toList();
      }
    } catch (_) {
      // silently fall through — caller shows empty list
    }
    return [];
  }
}
