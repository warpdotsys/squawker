import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'download_progress_sheet.dart';

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
        tooltip: 'Download this tweet',
      );
    }

    return TextButton.icon(
      icon: const Icon(Symbols.download, size: 18),
      label: const Text('Download', style: TextStyle(fontSize: 14)),
      onPressed: () => _startDownload(context),
    );
  }

  void _startDownload(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DownloadProgressSheet(tweetUrl: tweetUrl),
    );
  }
}
