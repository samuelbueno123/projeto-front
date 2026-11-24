import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_front/core/config/api_config.dart';

void main() {
  tearDown(() {
    ApiConfig.setRuntimeBaseUrlForTest(null);
  });

  test('auto-resolves LAN host on Flutter Web when default/auto is used', () {
    final resolved = ApiConfig.resolveBaseUrl(
      isWeb: true,
      currentUri: Uri.parse('http://192.168.15.80:5500/#/'),
      envBaseUrlOverride: 'http://localhost:8080',
    );
    expect(resolved, 'http://192.168.15.80:8080');

    final resolvedAuto = ApiConfig.resolveBaseUrl(
      isWeb: true,
      currentUri: Uri.parse('http://10.0.0.24:5500/'),
      envBaseUrlOverride: 'auto',
    );
    expect(resolvedAuto, 'http://10.0.0.24:8080');
  });

  test('respects explicit non-localhost API_BASE_URL over Web origin', () {
    final resolved = ApiConfig.resolveBaseUrl(
      isWeb: true,
      currentUri: Uri.parse('http://192.168.15.80:5500/'),
      envBaseUrlOverride: 'https://api.ancora.com',
    );
    expect(resolved, 'https://api.ancora.com');
  });

  test('runtime override takes precedence over everything', () {
    ApiConfig.setRuntimeBaseUrlForTest('192.168.1.55:8080/');
    expect(ApiConfig.runtimeOverrideBaseUrl, 'http://192.168.1.55:8080');

    final resolved = ApiConfig.resolveBaseUrl(
      isWeb: false,
      envBaseUrlOverride: 'http://localhost:8080',
    );
    expect(resolved, 'http://192.168.1.55:8080');
  });

  test('resolveMediaUrl preserves assets and rewrites localhost media URLs for LAN', () {
    expect(
      ApiConfig.resolveMediaUrl('assets/images/ancora_logo.png'),
      'assets/images/ancora_logo.png',
    );

    ApiConfig.setRuntimeBaseUrlForTest('http://192.168.15.80:8080');
    expect(
      ApiConfig.resolveMediaUrl('media/pictures/profiles/user_1.png'),
      'http://192.168.15.80:8080/media/pictures/profiles/user_1.png',
    );
    expect(
      ApiConfig.resolveMediaUrl('http://localhost:8080/media/pictures/condo.jpg'),
      'http://192.168.15.80:8080/media/pictures/condo.jpg',
    );
  });
}
