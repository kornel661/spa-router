import 'package:unittest/unittest.dart';
import 'package:unittest/html_config.dart';

import 'package:web_router/src/routeuri.dart';

main() {
  useHtmlConfiguration();

  test('Test comment example, without a hash, mode=hash', () {
    RouteUri uri = new RouteUri.parse(
        'http://domain.com/other/path?queryParam3=false#/example/path?queryParam1=true&queryParam2=example%20string',
        false);
    expect(uri.path, equals('/example/path'));
    expect(uri.hash, equals(''));
    expect(
        uri.search, equals('?queryParam1=true&queryParam2=example%20string'));
    expect(uri.isHashPath, equals(true));
  });

  test('Test comment example, without any hash, mode=hash', () {
    RouteUri uri = new RouteUri.parse(
        'http://domain.com/other/path?queryParam3=false/example/path?queryParam1=true&queryParam2=example%20string',
        false);
    expect(uri.path, equals('/'));
    expect(uri.hash, equals(''));
    expect(uri.search, equals(''));
    expect(uri.isHashPath, equals(true));
  });

  test('Test comment example, without a hash, mode=fullPath', () {
    RouteUri uri = new RouteUri.parse(
        'http://domain.com/other/path?queryParam3=false#/example/path?queryParam1=true&queryParam2=example%20string',
        true);
    expect(uri.path, equals('http://domain.com/other/path'));
    expect(uri.hash,
        equals('#/example/path?queryParam1=true&queryParam2=example%20string'));
    expect(uri.search, equals('?queryParam3=false'));
    expect(uri.isHashPath, equals(false));
  });

  test('empty uri', () {
    for (int i = 0; i < 1; i++) {
      RouteUri uri = new RouteUri.parse('', i == 0);
      expect(uri.path, equals('/'));
      expect(uri.hash, equals(''));
      expect(uri.search, equals(''));
      expect(uri.isHashPath, i == 1);
    }
  });
}
