String? extractTailscaleAuthUrlFromLogs(String logs) {
  final match = RegExp(r'https://login\.tailscale\.com/a/[A-Za-z0-9]+')
      .firstMatch(logs);
  return match?.group(0);
}
