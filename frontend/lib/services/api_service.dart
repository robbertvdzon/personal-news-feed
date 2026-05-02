import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/category.dart';
import '../models/news_item.dart';
import '../models/news_request.dart';

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

  static Future<void> saveSettings(List<Category> categories) async {
    await _client.put(
      Uri.parse('${AppConfig.apiBaseUrl}/api/settings'),
      headers: _headers,
      body: jsonEncode(categories.map((c) => c.toJson()).toList()),
    );
  }

  static Future<void> markRead(String id) async {
    await _client.put(
      Uri.parse('${AppConfig.apiBaseUrl}/api/news/$id/read'),
      headers: _headers,
    );
  }

  static Future<NewsRequest> createRequest({
    required String subject,
    String? sourceItemId,
    String? sourceItemTitle,
    int preferredCount = 2,
    int maxCount = 5,
  }) async {
    final body = jsonEncode({
      'subject': subject,
      if (sourceItemId != null) 'sourceItemId': sourceItemId,
      if (sourceItemTitle != null) 'sourceItemTitle': sourceItemTitle,
      'preferredCount': preferredCount,
      'maxCount': maxCount,
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
