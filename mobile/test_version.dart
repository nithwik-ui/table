void main() {
  print(_isNewerVersion('1.0.4+6', 'v1.0.4'));
  print(_isNewerVersion('1.0.3', 'v1.0.4'));
  print(_isNewerVersion('1.0.4', '1.0.4'));
}

bool _isNewerVersion(String current, String latest) {
  try {
    final cleanCurrent = current.replaceAll('v', '').replaceAll('+', '.');
    final cleanLatest = latest.replaceAll('v', '').replaceAll('+', '.');
    final currentParts = cleanCurrent.split('.').map(int.parse).toList();
    final latestParts = cleanLatest.split('.').map(int.parse).toList();
    for (int i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length) {
        return true;
      }
      if (latestParts[i] > currentParts[i]) {
        return true;
      } else if (latestParts[i] < currentParts[i]) {
        return false;
      }
    }
  } catch (_) {}
  return false;
}
