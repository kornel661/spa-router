library uri_matcher;

/// UriMatcher functions take String [uri] argument. If uri doesn't match then
/// null is returned. Otherwise a map of named matches
///   name_of_segment -> matched_segment
/// is returned.
typedef Map<String, String> UriMatcher(String uri);

/// Constructs a new UriMatcher for given pattern (path) [patt].
UriMatcher newMatcher(String patt) {
  return new _matcher(patt);
}

typedef bool _Fun(String);

/// Instances of this class satisfy UriMatcher type. They check if given uri
/// satisfies pattern supplied to the constructor and calculate a "model".
class _matcher {
  /// Uri being matched.
  String _uri;
  /// [_uri] semented and decoded.
  List<String> _uriSegments;
  /// List of matching functions [_Fun] (they are applied to correponding
  /// elements of [_uriSegments] to check if the [_uri] matches).
  final List<_Fun> _pat = new List<_Fun>();
  /// null if [_uri] doesn't match, :name -> match mapping otherwise.
  Map<String, String> _model;

  Map<String, String> call(String uri) {
    if (_uri == uri) {
      // return [_model] calculated from last run
      return _model;
    }
    _uri = uri;
    _uriSegments = new List<String>();
    for (String seg in uri.split('/')) {
      _uriSegments.add(Uri.decodeComponent(seg));
    }
    if (_pat.length > _uriSegments.length) {
      // match not possible
      _model = null;
      return null;
    }
    if (_pat.length < _uriSegments.length) {
      // the last pattern needs to be '**'
      if (_pat.isEmpty || _pat.last != _matchAll) {
        _model = null;
        return null;
      }
    }
    for (int i = 0; i < _pat.length; i++) {
      if (!_pat[i](_uriSegments[i])) {
        // matching failed
        _model = null;
        break;
      }
    }
    return _model;
  }

  bool doubleStar = false;
  _matcher(String patt) {
    for (String pat in patt.split('/')) {
      if (doubleStar) {
        // there can be only one '**' (as the last segment)
        _pat.clear();
        _pat.add(_matchNone);
        return;
      }
      if (pat == '*') {
        _pat.add(_namedMatcher(null));
      } else if (pat == '**') {
        _pat.add(_matchAll);
        doubleStar = true;
      } else if (pat.startsWith(':') && pat.length > 1) {
        _pat.add(_namedMatcher(pat.substring(1)));
      } else {
        _pat.add(_exactMatcher(Uri.decodeComponent(pat)));
      }
    }
  }

  /// Returns a matching function [_Fun] that matches only if [patt] matches literraly.
  _Fun _exactMatcher(String patt) {
    return (String s) {
      return s == patt;
    };
  }
  /// Returns a matching function [_Fun] that records the matched segment in the
  /// [_model] under name [name].
  _Fun _namedMatcher(String name) {
    return (String s) {
      if (name != null) {
        _model[name] = s;
      }
      return true;
    };
  }
}

/// Match all matching function [_Fun] -- for '**';
final _Fun _matchAll = (String) => true;
/// Match none matching function [_Fun] -- when we know pattern can't match anything.
final _Fun _matchNone = (String) => false;
