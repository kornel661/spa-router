import 'package:unittest/unittest.dart';
import 'package:unittest/html_config.dart';

import 'package:web_router/src/routeuri.dart';

main() {
  useHtmlConfiguration();

  test('Test comment example, without a hash', () {
    RouteUri uri = new RouteUri.parse(
        'http://domain.com/other/path?queryParam3=false#/example/path?queryParam1=true&queryParam2=example string',
        'auto');
    expect(uri.path, equals('/example/path'));
    expect(uri.hash, equals(''));
    expect(
        uri.search, equals('?queryParam1=true&queryParam2=example%20string'));
    expect(uri.isHashPath, equals(true));
  });

  test('Test comment example, without any hash, mode=hash', () {
    RouteUri uri = new RouteUri.parse(
        'http://domain.com/other/path?queryParam3=false/example/path?queryParam1=true&queryParam2=example string',
        'hash');
    expect(uri.path, equals('/'));
    expect(uri.hash, equals(''));
    expect(uri.search, equals(''));
    expect(uri.isHashPath, equals(true));
  });

  test('Test comment example, without a hash, mode=pushstate', () {
    RouteUri uri = new RouteUri.parse(
        'http://domain.com/other/path?queryParam3=false#/example/path?queryParam1=true&queryParam2=example string',
        'pushstate');
    expect(uri.path, equals('/other/path'));
    expect(uri.hash, equals('#/example/path?queryParam1=true&queryParam2=example%20string'));
    expect(
        uri.search, equals('?queryParam3=false'));
    expect(uri.isHashPath, equals(false));
  });

  test('Test comment example, without a hash, modes auto=hash', () {
    RouteUri uriAuto = new RouteUri.parse(
        'http://domain.com/other/path?queryParam3=false#/example/path?queryParam1=true&queryParam2=example string',
        'auto');
    RouteUri uriHash = new RouteUri.parse(
        'http://domain.com/other/path?queryParam3=false#/example/path?queryParam1=true&queryParam2=example string',
        'hash');
    expect(uriAuto.path, equals(uriHash.path));
    expect(uriAuto.hash, equals(uriHash.hash));
    expect(uriAuto.search, equals(uriHash.search));
    expect(uriAuto.isHashPath, equals(uriHash.isHashPath));
  });
}
