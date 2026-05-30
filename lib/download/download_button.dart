import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:squawker/generated/l10n.dart';
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
        tooltip: L10n.of(context).download_this_tweet,
      );
    }

    return TextButton.icon(
      icon: const Icon(Symbols.download, size: 18),
      label: Text(L10n.of(context).download, style: const TextStyle(fontSize: 14)),
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
