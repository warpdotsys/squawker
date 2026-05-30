import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:squawker/generated/l10n.dart';
import 'package:url_launcher/url_launcher.dart';
import 'download_service.dart';

class DownloadProgressSheet extends StatefulWidget {
  final String tweetUrl;

  const DownloadProgressSheet({super.key, required this.tweetUrl});

  @override
  State<DownloadProgressSheet> createState() => _DownloadProgressSheetState();
}

class _DownloadProgressSheetState extends State<DownloadProgressSheet> {
  final _service = DownloadService();
  DownloadProgress? _progress;
  bool _isDownloading = false;
  StreamSubscription<DownloadProgress>? _subscription;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _startDownload() {
    setState(() {
      _isDownloading = true;
      _progress = DownloadProgress(
        state: DownloadState.connecting,
        message: L10n.of(context).connecting_to_server,
      );
    });

    _subscription = _service.downloadTweet(widget.tweetUrl).listen(
      (progress) {
        if (mounted) {
          setState(() => _progress = progress);

          if (progress.state == DownloadState.completed ||
              progress.state == DownloadState.error) {
            setState(() => _isDownloading = false);
          }
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _progress = DownloadProgress(
              state: DownloadState.error,
              message: '${L10n.of(context).download_failed}: $e',
            );
          });
        }
      },
    );
  }

  void _retry() {
    _subscription?.cancel();
    _startDownload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.download_tweet_title,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            widget.tweetUrl,
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          _buildStatusWidget(theme, l10n),
          const SizedBox(height: 24),
          if (_progress?.state == DownloadState.completed &&
              _progress?.downloadUrl != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Symbols.open_in_browser),
                label: Text(l10n.open_download_link),
                onPressed: () => launchUrl(Uri.parse(_progress!.downloadUrl!)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          if (_progress?.state == DownloadState.error)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Symbols.refresh),
                label: Text(l10n.retry),
                onPressed: _isDownloading ? null : _retry,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          if (_progress?.state == DownloadState.completed ||
              _progress?.state == DownloadState.error)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.close),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatusWidget(ThemeData theme, L10n l10n) {
    if (_progress == null) return const SizedBox();

    IconData icon;
    Color color;
    Widget? progressIndicator;

    switch (_progress!.state) {
      case DownloadState.connecting:
        icon = Symbols.cloud_upload;
        color = theme.colorScheme.primary;
        progressIndicator = const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        break;
      case DownloadState.downloading:
        icon = Symbols.download;
        color = theme.colorScheme.primary;
        progressIndicator = const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        break;
      case DownloadState.archiving:
        icon = Symbols.archive;
        color = theme.colorScheme.secondary;
        progressIndicator = const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        break;
      case DownloadState.completed:
        icon = Symbols.check_circle;
        color = Colors.green;
        progressIndicator = null;
        break;
      case DownloadState.error:
        icon = Symbols.error;
        color = theme.colorScheme.error;
        progressIndicator = null;
        break;
      case DownloadState.idle:
        icon = Symbols.hourglass_empty;
        color = theme.disabledColor;
        progressIndicator = null;
        break;
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            _progress!.message,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        if (progressIndicator != null) progressIndicator,
      ],
    );
  }
}
