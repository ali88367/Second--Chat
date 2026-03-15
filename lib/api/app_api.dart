import 'auth/auth_api.dart';
import 'auth/oauth_api.dart';
import 'http/api_client.dart';
import 'platforms/platforms_api.dart';
import 'storage/secure_token_store.dart';
import 'storage/token_store.dart';

class AppApi {
  AppApi._(this.tokenStore, this.client)
      : auth = AuthApi(client.dio),
        oauth = OAuthApi(client.dio),
        platforms = PlatformsApi(client.dio);

  final TokenStore tokenStore;
  final ApiClient client;

  final AuthApi auth;
  final OAuthApi oauth;
  final PlatformsApi platforms;

  static AppApi create() {
    final tokenStore = SecureTokenStore();
    final client = ApiClient(tokenStore: tokenStore);
    return AppApi._(tokenStore, client);
  }
}
