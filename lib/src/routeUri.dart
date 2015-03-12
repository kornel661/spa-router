library routeUri;

/// Class representing URIs hadled by routes.
///
/// Example parseUrl('http://domain.com/other/path?queryParam3=false#/example/path?queryParam1=true&queryParam2=example%20string#middle', 'auto')
/// gives:
///   path: '/example/path',
///   hash: '#middle'
///   search: '?queryParam1=true&queryParam2=example%20string',
///   isHashPath: true
class RouteUri {
  Uri uri;
  bool isHashPath = false;

  /// hash for routing for this uri ('...#/...?...#XXX')
  String get hash {
    if (uri.fragment.length == 0) return '';
    return '#' + uri.fragment;
  }

  /// path for routing for this uri ('...#/XXX?...#...')
  String get path {
    return uri.path;
  }

  /// query string for routing for this uri ('...#/...?XXX#...')
  String get search {
    if (uri.query.length == 0) return '';
    return '?' + uri.query;
  }

  String toString() => uri.toString() + " isHashPath: ${isHashPath}";

  /// Map represenation of this RouteUri.
  Map<String, Object> toMap() {
    Map<String, Object> map = new Map<String, Object>();
    map['path'] = this.path;
    map['hash'] = this.hash;
    map['search'] = this.search;
    map['isHashPath'] = this.isHashPath;
    return map;
  }

  /// parseUrl(location, mode) - Augment the native URL() constructor to get info about hash paths
  ///  mode = "auto|hash|pushstate"
  ///
  /// Example:
  ///  parseUrl('http://domain.com/other/path?queryParam3=false#/example/path?queryParam1=true&queryParam2=example%20string#middle', 'auto')
  ///
  /// returns {
  ///   path: '/example/path',
  ///   hash: '#middle'
  ///   search: '?queryParam1=true&queryParam2=example%20string',
  ///   isHashPath: true
  /// }
  ///
  /// Note: The location must be a fully qualified URL with a protocol like 'http(s)://'
  RouteUri.parse(String uriIn, String mode) {
    uri = Uri.parse(uriIn);
    isHashPath = (mode == "hash");

    if (mode != "pushstate") {
      // auto or hash

      // check for a hash path
      if (uri.fragment.startsWith('/')) {
        // '#/'
        // hash path
        isHashPath = true;
        uri = _replacePathAndQuery(uri, uri.fragment);
      } else if (uri.fragment.startsWith('!/')) {
        // '#!/'
        // hashbang path
        isHashPath = true;
        uri = _replacePathAndQuery(uri, uri.fragment.substring(1));
      } else if (isHashPath) {
        // still use the hash if mode="hash"
        if (uri.fragment.length == 0) {
          uri = uri.replace(path: '/', query: '');
        } else {
          uri = _replacePathAndQuery(uri, uri.fragment);
        }
      }

      if (isHashPath) {
        uri = uri.replace(fragment: '');

        // hash paths might have an additional hash in the hash path for scrolling to a specific part of the page #/hash/path#elementId
        int secondHashIndex = uri.path.indexOf('#');
        if (secondHashIndex != -1) {
          uri = uri.replace(fragment: uri.path.substring(secondHashIndex));
          uri = uri.replace(path: uri.path.substring(0, secondHashIndex));
        }

        // hash paths get the search from the hash if it exists
        int searchIndex = uri.path.indexOf('?');
        if (searchIndex != -1) {
          uri = uri.replace(query: uri.path.substring(searchIndex));
          uri = uri.replace(path: uri.path.substring(0, searchIndex));
        }
      }
    }
  }
}

/// Given a pathAndQuery string (e.g., '/a/b/c?test=ok) creates a new Uri with
/// path and query fields of the uri replaced with the ones form the
/// pathAndQuery string, eg.,
///  path: /a/b/c
///  query: test=ok
///
Uri _replacePathAndQuery(Uri uri, String pathAndQuery) {
  String path = pathAndQuery;
  String query = "";
  int index = pathAndQuery.indexOf("?");
  if (index != -1) {
    path = pathAndQuery.substring(0, index); // get rid of query
    query = pathAndQuery.substring(index + 1); // just the query
  }
  uri = uri.replace(path: path, query: query);
  return uri;
}
