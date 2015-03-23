/*
 * SPA router
 * Copyright (c) 2015 Kornel Maczyński.
 * For other contributors, see Github.
 */
library routeuri;

/// Class representing URIs handled by routes.
///
/// Example parse('http://domain.com/other/path?queryParam3=false#/example/path?queryParam1=true&queryParam2=example%20string#middle', false)
/// gives:
///   path: '/example/path',
///   hash: '#middle'
///   search: '?queryParam1=true&queryParam2=example%20string',
///   isHashPath: true
class RouteUri {
  /// hash for routing for this uri ('...#/...?...@@XXX')
  /// e.g. `#name`
  String hash;
  /// path for routing for this uri ('...#/XXX?...@@...')
  /// e.g. `/path`
  String path;
  /// query string for routing for this uri ('...#/...?XXX@@...')
  /// e.g. `?arg=val`
  String search;
  /// Is it a 'hash' path?
  bool isHashPath = false;
  @override
  String toString() => "${path}${search}${hash}";

  /// Parses given [uri] (location). No encoding/decoding takes place.
  ///
  /// If [fullPath] is false then only part after first '#' is taken into
  /// account. In this case [hashFragSep] acts as a fragment (hash) separator.
  ///
  /// Example:
  /// ```
  /// parse('http://domain.com/other/path?queryParam3=false#/example/path?queryParam1=true&queryParam2=example%20string@@middle', false)
  /// ```
  ///
  /// returns: {
  ///   path: '/example/path',
  ///   hash: '#middle'
  ///   search: '?queryParam1=true&queryParam2=example%20string',
  ///   isHashPath: true
  /// }
  RouteUri.parse(String uri, [bool fullPath = false, String hashFragSep = '@@']) {
    if (fullPath) {
    	hashFragSep = '#';
    } else {
    	// hash path
    	isHashPath = true;
      // we want to work with hash only
      int i = uri.indexOf('#');
      if (i == -1) {
        uri = "";
      } else {
      	// get rid of 'xxx/xx#'
        uri = uri.substring(i + 1);
      }
    }
    if (uri == "") {
    	uri = "/";
    }
    int qi = uri.indexOf('?');
    if (qi == -1) {
      search = "";
      String pathHash = uri;
      int hi = pathHash.indexOf(hashFragSep);
      if (hi == -1) {
        path = pathHash;
        hash = "";
      } else {
        path = pathHash.substring(0, hi);
        hash = '#' + pathHash.substring(hi + hashFragSep.length);
      }
    } else {
      path = uri.substring(0, qi);
      String queryHash = uri.substring(qi);
      int hi = queryHash.indexOf(hashFragSep);
      if (hi == -1) {
        search = queryHash;
        hash = "";
      } else {
        search = queryHash.substring(0, hi);
        hash = '#' + queryHash.substring(hi + hashFragSep.length);
      }
    }
  }
}
