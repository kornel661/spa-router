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
	
	String get hash {
		if (uri.fragment.length == 0) return '';
		return '#' + uri.fragment;
	}
	
	String get path {
		return uri.path;
	}
	
	String get search {
		if (uri.query.length == 0) return '';
		return '?' + uri.query;
	}
	
	String toString() => uri.toString() + " isHashPath: ${isHashPath}";
	
	/// Map represenation of this RouteUri.
	Map<String, dynamic> toMap() {
		Map<String, dynamic> map = new Map<String, dynamic>();
		map['path'] = this.path;
		map['hash'] = this.hash;
		map['search'] = this.search;
		map['isHashPath'] = this.isHashPath;
		return map;
	}
	
	Uri replacePathAndQuery(Uri uri, String pathAndQuery) {
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
	
	/// parseUrl(location, mode) - Augment the native URL() constructor to get info about hash paths
	/// mode = "auto|hash|pushstate"
	///
	/// Example parseUrl('http://domain.com/other/path?queryParam3=false#/example/path?queryParam1=true&queryParam2=example%20string#middle', 'auto')
	///
	/// returns {
	///   path: '/example/path',
	///   hash: '#middle'
	///   search: '?queryParam1=true&queryParam2=example%20string',
	///   isHashPath: true
	/// }
	///
	/// Note: The location must be a fully qualified URL with a protocol like 'http(s)://'
	RouteUri.parse(String uriIn, String mode){
		uri = Uri.parse(uriIn);
		isHashPath = (mode == "hash");
		
		if (mode != "pushstate") {
			// auto or hash
			
			// check for a hash path
			if (uri.fragment.startsWith('/')) {// '#/'
				// hash path
				isHashPath = true;
				uri = replacePathAndQuery(uri, uri.fragment);
			} else if (uri.fragment.startsWith('!/')) {// '#!/'
				// hashbang path
				isHashPath = true;
				uri = replacePathAndQuery(uri, uri.fragment.substring(1));
			} else if (isHashPath) {
				// still use the hash if mode="hash"
				if (uri.fragment.length == 0) {
					uri = uri.replace(path: '/');
				} else {
					uri = replacePathAndQuery(uri, uri.fragment);
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
