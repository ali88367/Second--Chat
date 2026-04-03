import 'dart:convert';

/// Reads the `exp` claim (seconds since epoch, UTC) from a JWT access token.
DateTime? parseJwtAccessTokenExpiryUtc(String accessToken) {
  try {
    final parts = accessToken.split('.');
    if (parts.length < 2) return null;
    var payload = parts[1];
    switch (payload.length % 4) {
      case 2:
        payload += '==';
        break;
      case 3:
        payload += '=';
        break;
    }
    payload = payload.replaceAll('-', '+').replaceAll('_', '/');
    final bytes = base64Decode(payload);
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) return null;
    final exp = decoded['exp'];
    if (exp is int) {
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    }
    if (exp is num) {
      return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
    }
  } catch (_) {}
  return null;
}
