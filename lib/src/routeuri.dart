library routeUri;

/// Class representing URIs hadled by routes.
///
/// Example parse('http://domain.com/other/path?queryParam3=false#/example/path?queryParam1=true&queryParam2=example%20string#middle', false)
/// gives:
///   path: '/example/path',
///   hash: '#middle'
///   search: '?queryParam1=true&queryParam2=example%20string',
///   isHashPath: true
class RouteUri {
  /// hash for routing for this uri ('...#/...?...#XXX')
  /// e.g. `#name`
  String hash;
  /// path for routing for this uri ('...#/XXX?...#...')
  /// e.g. `/path`
  String path;
  /// query string for routing for this uri ('...#/...?XXX#...')
  /// e.g. `?arg=val`
  String search;
  /// Is it a 'hash' path?
  bool isHashPath = false;
  @override
  String toString() => "${path}${search}${hash}";

  /// parse(location, fullPath) - parses given uri (location). If fullPath is
  ///   false then only part after first '#' is taken into account.
  ///
  /// Example:
  ///  parse('http://domain.com/other/path?queryParam3=false#/example/path?queryParam1=true&queryParam2=example%20string#middle', false)
  ///
  /// returns {
  ///   path: '/example/path',
  ///   hash: '#middle'
  ///   search: '?queryParam1=true&queryParam2=example%20string',
  ///   isHashPath: true
  /// }
  RouteUri.parse(String uri, [bool fullPath = false]) {
    if (!fullPath) {
    	isHashPath = true;
      // we want to work with hash only
      int i = uri.indexOf('#');
      if (i == -1) {
        uri = "";
      } else {
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
      int hi = pathHash.indexOf('#');
      if (hi == -1) {
        path = pathHash;
        hash = "";
      } else {
        path = pathHash.substring(0, hi);
        hash = pathHash.substring(hi);
      }
    } else {
      path = uri.substring(0, qi);
      String queryHash = uri.substring(qi);
      int hi = queryHash.indexOf('#');
      if (hi == -1) {
        search = queryHash;
        hash = "";
      } else {
        search = queryHash.substring(0, hi);
        hash = queryHash.substring(hi);
      }
    }
  }
}
