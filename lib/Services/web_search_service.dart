import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:reins/Models/ollama_exception.dart';
import 'package:reins/Utils/http_error_formatter.dart';

/// Client for Ollama's hosted Web Search and Web Fetch APIs.
///
/// Both endpoints require an Ollama API key (the same one used for Ollama Cloud
/// in this app). See https://docs.ollama.com/capabilities/web-search.
class WebSearchService {
  static const String _baseUrl = 'https://ollama.com';

  String? _apiToken;
  set apiToken(String? value) =>
      _apiToken = (value != null && value.isNotEmpty) ? value : null;

  WebSearchService({String? apiToken})
      : _apiToken = (apiToken != null && apiToken.isNotEmpty) ? apiToken : null;

  bool get isConfigured => _apiToken != null;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_apiToken != null) 'Authorization': 'Bearer $_apiToken',
      };

  /// Performs a web search for [query], returning up to [maxResults] results.
  ///
  /// Ollama caps `max_results` at 10.
  Future<List<WebSearchResult>> search(
    String query, {
    int maxResults = 5,
  }) async {
    if (!isConfigured) {
      throw OllamaException(
        'Web search requires an Ollama API token. Set it in Settings.',
      );
    }

    final clamped = maxResults.clamp(1, 10);
    final response = await http.post(
      Uri.parse('$_baseUrl/api/web_search'),
      headers: _headers,
      body: json.encode({'query': query, 'max_results': clamped}),
    );

    if (response.statusCode != 200) {
      throw OllamaException(
        HttpErrorFormatter.formatHttpError(response.statusCode, body: response.body),
      );
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    final results = (body['results'] as List? ?? const [])
        .whereType<Map>()
        .map((r) => WebSearchResult.fromJson(Map<String, dynamic>.from(r)))
        .toList();
    return results;
  }

  /// Fetches the parsed contents of a single web page.
  Future<WebFetchResult> fetch(String url) async {
    if (!isConfigured) {
      throw OllamaException(
        'Web fetch requires an Ollama API token. Set it in Settings.',
      );
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/api/web_fetch'),
      headers: _headers,
      body: json.encode({'url': url}),
    );

    if (response.statusCode != 200) {
      throw OllamaException(
        HttpErrorFormatter.formatHttpError(response.statusCode, body: response.body),
      );
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    return WebFetchResult.fromJson(body);
  }
}

class WebSearchResult {
  final String title;
  final String url;
  final String content;

  const WebSearchResult({
    required this.title,
    required this.url,
    required this.content,
  });

  factory WebSearchResult.fromJson(Map<String, dynamic> json) => WebSearchResult(
        title: (json['title'] ?? '') as String,
        url: (json['url'] ?? '') as String,
        content: (json['content'] ?? '') as String,
      );
}

class WebFetchResult {
  final String title;
  final String content;
  final List<String> links;

  const WebFetchResult({
    required this.title,
    required this.content,
    required this.links,
  });

  factory WebFetchResult.fromJson(Map<String, dynamic> json) => WebFetchResult(
        title: (json['title'] ?? '') as String,
        content: (json['content'] ?? '') as String,
        links: (json['links'] as List? ?? const [])
            .whereType<String>()
            .toList(),
      );
}
