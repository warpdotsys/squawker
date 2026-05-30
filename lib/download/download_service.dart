import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum DownloadState { idle, connecting, downloading, archiving, completed, error }

class DownloadProgress {
  final DownloadState state;
  final String message;
  final String? downloadUrl;

  DownloadProgress({
    required this.state,
    required this.message,
    this.downloadUrl,
  });
}

class DownloadService {
  static const String _defaultApiBase = 'https://get.warpdotsys.com/download';
  static const String _prefApiEndpoint = 'download_api_endpoint';
  static const String _prefArchiveMode = 'download_archive_mode';

  static String _apiBase = _defaultApiBase;
  static bool _archiveMode = true;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiBase = prefs.getString(_prefApiEndpoint) ?? _defaultApiBase;
    _archiveMode = prefs.getBool(_prefArchiveMode) ?? true;
  }

  static Future<void> setApiEndpoint(String endpoint) async {
    _apiBase = endpoint;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefApiEndpoint, endpoint);
  }

  static Future<void> setArchiveMode(bool archive) async {
    _archiveMode = archive;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefArchiveMode, archive);
  }

  static String get apiEndpoint => _apiBase;
  static bool get archiveMode => _archiveMode;

  Stream<DownloadProgress> downloadTweet(String tweetUrl) async* {
    final uri = Uri.parse('$_apiBase?url=${Uri.encodeComponent(tweetUrl)}&archive=$_archiveMode');

    yield DownloadProgress(state: DownloadState.connecting, message: 'Connecting to server...');

    try {
      final request = http.Request('GET', uri);
      final response = await http.Client().send(request);

      String buffer = '';
      String lastMessage = '';
      String? downloadUrl;

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;

        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final message = line.substring(6).trim();
            if (message.isNotEmpty && message != lastMessage) {
              lastMessage = message;

              if (message.startsWith('http')) {
                downloadUrl = message;
                yield DownloadProgress(
                  state: DownloadState.completed,
                  message: 'Download ready!',
                  downloadUrl: downloadUrl,
                );
                return;
              }

              if (message.contains('[System] Archiving')) {
                yield DownloadProgress(
                  state: DownloadState.archiving,
                  message: 'Archiving files...',
                );
              } else if (message.contains('[System] Download finished')) {
                yield DownloadProgress(
                  state: DownloadState.completed,
                  message: 'Download completed!',
                );
                return;
              } else if (message.contains('Error') || message.contains('error')) {
                yield DownloadProgress(
                  state: DownloadState.error,
                  message: message,
                );
                return;
              } else {
                yield DownloadProgress(
                  state: DownloadState.downloading,
                  message: message,
                );
              }
            }
          } else if (line.startsWith('event: archive')) {
            yield DownloadProgress(
              state: DownloadState.archiving,
              message: 'Archiving files...',
            );
          } else if (line.startsWith('event: close')) {
            if (downloadUrl != null) {
              yield DownloadProgress(
                state: DownloadState.completed,
                message: 'Download ready!',
                downloadUrl: downloadUrl,
              );
            } else {
              yield DownloadProgress(
                state: DownloadState.completed,
                message: 'Task completed',
              );
            }
            return;
          }
        }
      }

      if (buffer.isNotEmpty) {
        if (buffer.startsWith('data: ')) {
          final content = buffer.substring(6).trim();
          if (content.startsWith('http')) {
            yield DownloadProgress(
              state: DownloadState.completed,
              message: 'Download ready!',
              downloadUrl: content,
            );
            return;
          }
        }
      }

      if (downloadUrl != null) {
        yield DownloadProgress(
          state: DownloadState.completed,
          message: 'Download ready!',
          downloadUrl: downloadUrl,
        );
      } else {
        yield DownloadProgress(
          state: DownloadState.completed,
          message: 'Task completed',
        );
      }
    } catch (e) {
      yield DownloadProgress(
        state: DownloadState.error,
        message: 'Download failed: $e',
      );
    }
  }

  static String extractTweetId(String url) {
    final regex = RegExp(r'/status/(\d+)');
    final match = regex.firstMatch(url);
    return match?.group(1) ?? '';
  }

  static String buildTweetUrl(String username, String tweetId) {
    return 'https://x.com/$username/status/$tweetId';
  }
}
