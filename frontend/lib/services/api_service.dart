import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/category.dart';
import '../models/news_item.dart';
import '../models/news_request.dart';
import '../models/podcast.dart';

class ApiService {
  static final _client = http.Client();
  static String? _token;

  static void setToken(String? token) => _token = token;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<List<NewsItem>> fetchNews() async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/api/news'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Fout bij ophalen nieuws: ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => NewsItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<NewsRequest>> fetchRequests() async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/api/requests'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Fout bij ophalen verzoeken: ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => NewsRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<Category>> fetchSettings() async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/api/settings'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Fout bij ophalen instellingen: ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<String>> suggestWebsites(String categoryId) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/api/settings/suggest-websites/$categoryId'),
      headers: _headers,
    );
    if (response.statusCode != 200) return [];
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => e as String).toList();
  }

  static Future<void> saveSettings(List<Category> categories) async {
    await _client.put(
      Uri.parse('${AppConfig.apiBaseUrl}/api/settings'),
      headers: _headers,
      body: jsonEncode(categories.map((c) => c.toJson()).toList()),
    );
  }

  static Future<void> refreshNews() async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/api/news/refresh'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Fout bij verversen nieuws: ${response.statusCode}');
    }
  }

  static Future<void> deleteNewsItem(String id) async {
    await _client.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/api/news/$id'),
      headers: _headers,
    );
  }

  static Future<int> cleanupNews({
    required int olderThanDays,
    required bool keepStarred,
    required bool keepLiked,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/news/cleanup').replace(
      queryParameters: {
        'olderThanDays': '$olderThanDays',
        'keepStarred': '$keepStarred',
        'keepLiked': '$keepLiked',
      },
    );
    final response = await _client.delete(uri, headers: _headers);
    if (response.statusCode != 200) return 0;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['removed'] as int? ?? 0;
  }

  static Future<void> deleteRequest(String id) async {
    await _client.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/api/requests/$id'),
      headers: _headers,
    );
  }

  static Future<NewsRequest> rerunRequest(String id) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/api/requests/$id/rerun'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Fout bij herstart verzoek: ${response.statusCode}');
    }
    return NewsRequest.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<void> markRead(String id) async {
    await _client.put(
      Uri.parse('${AppConfig.apiBaseUrl}/api/news/$id/read'),
      headers: _headers,
    );
  }

  static Future<void> toggleStar(String id) async {
    await _client.put(
      Uri.parse('${AppConfig.apiBaseUrl}/api/news/$id/star'),
      headers: _headers,
    );
  }

  // ── Podcasts ─────────────────────────────────────────────────────────────────

  static Future<List<Podcast>> fetchPodcasts() async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/api/podcasts'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Fout bij ophalen podcasts: ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => Podcast.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Podcast> createPodcast({
    required int periodDays,
    required int durationMinutes,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/api/podcasts'),
      headers: _headers,
      body: jsonEncode({'periodDays': periodDays, 'durationMinutes': durationMinutes}),
    );
    if (response.statusCode != 201) {
      throw Exception('Fout bij aanmaken podcast: ${response.statusCode}');
    }
    return Podcast.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<void> deletePodcast(String id) async {
    await _client.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/api/podcasts/$id'),
      headers: _headers,
    );
  }

  static String podcastAudioUrl(String id) =>
      '${AppConfig.apiBaseUrl}/api/podcasts/$id/audio';

  static String? get currentToken => _token;

  // ─────────────────────────────────────────────────────────────────────────────

  static Future<void> setFeedback(String id, bool? liked) async {
    await _client.put(
      Uri.parse('${AppConfig.apiBaseUrl}/api/news/$id/feedback'),
      headers: _headers,
      body: jsonEncode({'liked': liked}),
    );
  }

  static Future<NewsRequest> createRequest({
    required String subject,
    String? sourceItemId,
    String? sourceItemTitle,
    int preferredCount = 2,
    int maxCount = 5,
    String extraInstructions = '',
  }) async {
    final body = jsonEncode({
      'subject': subject,
      if (sourceItemId != null) 'sourceItemId': sourceItemId,
      if (sourceItemTitle != null) 'sourceItemTitle': sourceItemTitle,
      'preferredCount': preferredCount,
      'maxCount': maxCount,
      if (extraInstructions.isNotEmpty) 'extraInstructions': extraInstructions,
    });
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/api/requests'),
      headers: _headers,
      body: body,
    );
    if (response.statusCode != 201) {
      throw Exception('Fout bij aanmaken verzoek: ${response.statusCode}');
    }
    return NewsRequest.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
