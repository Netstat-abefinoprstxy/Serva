import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> showGlobalTailscaleAuthSnackBar(String url) async {
  final messenger = rootScaffoldMessengerKey.currentState;
  print('[tailscale-auth] showGlobalTailscaleAuthSnackBar url=$url');
  print('[tailscale-auth] messengerReady=${messenger != null}');
  if (messenger == null) return;

  void openAuthUrl() {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  messenger.hideCurrentSnackBar();
  print('[tailscale-auth] showing snackbar');
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 10),
      behavior: SnackBarBehavior.floating,
      content: InkWell(
        onTap: () {
          print('[tailscale-auth] snackbar body tapped');
          openAuthUrl();
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            url,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      action: SnackBarAction(
        label: 'Open',
        onPressed: () {
          print('[tailscale-auth] snackbar action pressed');
          openAuthUrl();
        },
      ),
    ),
  );
}
