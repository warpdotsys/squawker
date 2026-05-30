import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:squawker/generated/l10n.dart';
import 'download_service.dart';

class DownloadButton extends StatelessWidget {
  final String tweetUrl;
  final bool isCompact;

  const DownloadButton({
    super.key,
    required this.tweetUrl,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isCompact) {
      return IconButton(
        icon: const Icon(Symbols.download, size: 18),
        color: theme.colorScheme.primary,
        onPressed: () => _startDownload(context),
        tooltip: L10n.of(context).download_this_tweet,
      );
    }

    return TextButton.icon(
      icon: const Icon(Symbols.download, size: 18),
      label: Text(L10n.of(context).download, style: const TextStyle(fontSize: 14)),
      onPressed: () => _startDownload(context),
    );
  }

  void _startDownload(BuildContext context) async {
    final l10n = L10n.of(context);
    final scaffold = ScaffoldMessenger.of(context);

    scaffold.showSnackBar(
      SnackBar(
        content: Text(l10n.download_started),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      await for (final message in DownloadService.downloadTweet(tweetUrl)) {
        // Just consume the stream, no need to display logs
      }

      if (context.mounted) {
        scaffold.clearSnackBars();
        scaffold.showSnackBar(
          SnackBar(
            content: Text(l10n.download_completed),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        scaffold.clearSnackBars();
        scaffold.showSnackBar(
          SnackBar(
            content: Text('${l10n.download_failed}: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
