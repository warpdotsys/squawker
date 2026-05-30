import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum DownloadState { idle, connecting, downloading, completed, error }

class DownloadService {
  static const String _defaultApiBase = 'https://get.warpdotsys.com/download';
  static const String _prefApiEndpoint = 'download_api_endpoint';
  static const String _prefTValue = 'download_t_value';

  static String _apiBase = _defaultApiBase;
  static int _tValue = 0;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiBase = prefs.getString(_prefApiEndpoint) ?? _defaultApiBase;
    _tValue = prefs.getInt(_prefTValue) ?? 0;
  }

  static Future<void> setApiEndpoint(String endpoint) async {
    _apiBase = endpoint;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefApiEndpoint, endpoint);
  }

  static Future<void> setTValue(int t) async {
    _tValue = t;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefTValue, t);
  }

  static String get apiEndpoint => _apiBase;
  static int get tValue => _tValue;

  static String getTValueLabel(int t) {
    switch (t) {
      case 0:
        return 'Full Scan';
      case 3:
        return 'Fast (T=3)';
      case 20:
        return 'Safe (T=20)';
      default:
        return 'Custom (T=$t)';
    }
  }

  Stream<String> downloadTweet(String tweetUrl) async* {
    var uri = '$_apiBase?url=${Uri.encodeComponent(tweetUrl)}';
    if (_tValue > 0) {
      uri += '&t=$_tValue';
    }

    try {
      final request = http.Request('GET', Uri.parse(uri));
      final response = await http.Client().send(request);

      String buffer = '';

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;

        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final message = line.substring(6).trim();
            if (message.isNotEmpty) {
              yield message;
            }
          }
        }
      }

      if (buffer.isNotEmpty && buffer.startsWith('data: ')) {
        final content = buffer.substring(6).trim();
        if (content.isNotEmpty) {
          yield content;
        }
      }
    } catch (e) {
      throw Exception('Download failed: $e');
    }
  }
}
