/*
 *  Web Router - dart
 *  Copyright (c) 2015 Kornel Maczyński, pjv, Erik Ringsmuth. For other contributors, see Github.
 */
@HtmlImport('package:/web_router/web_router.html')
library web_router;

import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'package:core_elements/core_animated_pages.dart';

import 'package:web_router/web_route.dart';
import 'package:web_router/src/routeuri.dart';
import 'package:web_router/src/events.dart';

/// web-router is a router element.
/// Example usage (square brackets indicate optional attributes):
///   <web-router
///     [manualInit]
///     [fullPaths]
///     [relaxedSlash]
///     [animated] [transitions="hero-transition cross-fade"]
///     [bindRouter]
///     [noScroll]
///     [prefix="/prefix/path"]>
///       <web-route ...></web-route>
///       ...
///   </web-router>
@CustomTag('web-router')
class WebRouter extends PolymerElement {
  /// If manualInit is set one has to initialize the router manually:
  ///   document.querySelector('web-router').initialize();
  @published bool manualInit = false;
  /// Use full paths for routing (default behaviour is to use hashes).
  @PublishedProperty(reflect: true)
  bool fullPaths = false;
  /// If relaxedSlash is set then trailing slashes are ignored during matching,
  /// i.e., '/home' matches '/home/' as well.
  @PublishedProperty(reflect: true)
  bool relaxedSlash = false;
  /// Whether to use Polymer's core-animated-pages for transitions.
  ///
  /// If the first child of the router is <core-animated-pages> then it is used
  /// for transitions (router's `transitions` attribute is ignored). This gives
  /// opportunity to configure <core-animated-pages>.
  /// Otherwise, router creates <core-animated-pages> on its own.
  @published bool animated = false;
  /// Which transitions of the core-animated-pages to use.
  /// E.g., transitions="hero-transition cross-fade"
  /// This attribute is forwarded to core-animated-pages.
  @published String transitions = "";
  /// Whether to bind the router to the route's CustomElement.
  /// (Equivalent to setting bindRouter on all routes.)
  @PublishedProperty(reflect: true)
  bool bindRouter = false;
  /// Don't scroll to hash.
  /// (Equivalent to setting noScroll on all routes.)
  @PublishedProperty(reflect: true)
  bool noScroll = false;
  /// Prefix added to all child routes' paths.
  @published String prefix = "";

  /// Is the router initilized already?
  bool _isInitialized = false;
  /// Active URL.
  RouteUri _activeUri;
  /// Previous active route.
  WebRoute _previousRoute;
  /// Currently active route.
  WebRoute _activeRoute;
  /// All routes.
  List<WebRoute> routes;

  /// Currently active URL.
  RouteUri get activeUri => _activeUri;
  /// Currently active route.
  WebRoute get activeRoute => _activeRoute;
  /// Currently active route.
  set activeRoute(WebRoute r) {
    if (animated && _previousRoute != null) {
      // make sure that the content is cleared even if there was an animation in progress
      _previousRoute.clearContent();
    }
    _previousRoute = _activeRoute;
    _activeRoute = r;
  }
  /// Previous active route.
  WebRoute get previousRoute => _previousRoute;

  /// CoreAnimatedPages element.
  CoreAnimatedPages _coreAnimatedPages;
  /// Subscription of popstate events (for address change monitoring).
  StreamSubscription<PopStateEvent> _popStateSubscription = null;
  /// Subscription of ends of transitions.
  StreamSubscription<TransitionEvent> _transitionEndSubscription = null;

  @override
  WebRouter.created() : super.created();

  @override
  void domReady() {
    super.domReady();
    if (!manualInit) {
      initialize();
    }
  }

  @override
  Node append(Node node) {
    // TODO(km): check if it works
    if (!_isInitialized) {
      super.append(node);
      return node;
    }
    if (!animated) {
      super.append(node);
    } else {
      _coreAnimatedPages.append(node);
    }
    if (node is WebRoute) {
      _prepareRoute(node, prefix);
      routes.add(node);
    }
    return node;
  }

  /// Sets route.router to this and add prefix to route.path.
  _prepareRoute(WebRoute route, String pref) {
    route.router = this;
    route.path = _joinPaths(pref, route.path);
  }

  /// Initialize the router: core-animated-pages and listen for change events.
  void initialize() {
    if (_isInitialized) {
      return;
    }
    //_activeUri = new RouteUri.parse(window.location.href, mode);
    //routes = this.querySelectorAll("web-route") as List<WebRoute>;
    routes = new List<WebRoute>();
    void walk(List<Element> l, String pref) {
      for (Element route in l) {
        if (route is WebRoute) {
          routes.add(route);
          _prepareRoute(route, pref);
          walk(route.children, _joinPaths(pref, route.path));
        }
      }
    }
    walk(this.children, prefix);

    if (animated) {
      if (this.children.first is CoreAnimatedPages) {
        _coreAnimatedPages = this.children.first;
      } else {
        _coreAnimatedPages = new CoreAnimatedPages();
        _coreAnimatedPages.setAttribute('transitions', transitions);
      }
      for (WebRoute route in routes) {
        _coreAnimatedPages.append(route);
      }
      _coreAnimatedPages.setAttribute('valueattr', 'path');
      this.append(_coreAnimatedPages);
      _coreAnimatedPages.onTransitionEnd.listen((TransitionEvent e) {
        if (_previousRoute != null) {
          _previousRoute.clearContent();
          _activeRoute.scrollToHash();
        }
      });
    }
    // listen for URL change events
    _popStateSubscription =
        window.onPopState.listen((PopStateEvent e) => _update());
    // mark router as initialized
    _isInitialized = true;
    // load the web component for the current route
    _update();
  }

  /// clean up global event listeners
  @override
  void detached() {
    super.detached();
    if (_popStateSubscription != null) {
      _popStateSubscription.cancel();
    }
    if (_transitionEndSubscription != null) {
      _transitionEndSubscription.cancel();
    }
  }

  /// go(path, {replace}) - Navigate to the path. E.g.,
  ///   go('/home')
  /// Uses window.history.pushState unless replace==true in which case
  /// window.history.replaceState is used.
  void go(String path, {bool replace: false}) {
    if (!fullPaths) {
      path = '#' + path;
    }
    if (replace) {
      window.history.replaceState(null, "", path);
    } else {
      window.history.pushState(null, "", path);
    }

    // dispatch a popstate event
    PopStateEvent popStateEvent = new Event.eventType(
        'PopStateEvent', 'popstate', canBubble: false, cancelable: false);
    window.dispatchEvent(popStateEvent);
  }

  /// Finds the first <web-route> that matches the current URL and changes the active route.
  /// Wired to PopStateEvents.
  void _update() {
    RouteUri url = new RouteUri.parse(window.location.href, fullPaths);
    // don't load a new route if only the hash fragment changed
    if (activeUri != null &&
        url.path == activeUri.path &&
        url.search == activeUri.search) {
      if (activeRoute != null) {
        activeRoute.uri = url;
        if (url.hash != activeUri.hash) {
          activeRoute.scrollToHash();
        }
        _activeUri = url;
      }
      return;
    }
    // fire a state-change event on the web-router and return early if the user
    // called event.preventDefault()
    Map<String, String> eventDetail = {'path': url.path};
    if (!fireEvent(WebEvent.stateChange, eventDetail, this)) {
      return;
    }
    // find the first matching route
    for (WebRoute route in routes) {
      if (route.isMatch(url, !relaxedSlash)) {
        _activeUri = url;
        route.activate(url);
        return;
      }
    }
    fireEvent(WebEvent.routeNotFound, eventDetail, this);
  }

  /// Plays the core-animated-pages animation (if required) and scrolls to hash.
  /// Doesn't update active route, etc.
  void playAnimation() {
    // animate the transition if core-animated-pages are being used
    if (animated) {
      if (_coreAnimatedPages.selected == _activeRoute.path) {
        activeRoute.scrollToHash();
      }
      _coreAnimatedPages.setAttribute('selected', _activeRoute.path);
      // clearing invisible routes & scrolling taken care in [initialize]
    } else {
      activeRoute.scrollToHash();
    }
  }
}

/// Joins (concatenates) two patch together. Adds or removes a slash between
/// them if necessary.
String _joinPaths(String a, String b) {
  if (a == null || a == "") {
    return b;
  }
  if (b == null || b == "") {
    return a;
  }
  // now both a & b have positive length,
  // let's get rid of spurious slashes
  String aEnd = a[a.length - 1];
  String bStart = b[0];
  if (aEnd == '/' && bStart == '/') {
    return a + b.substring(1);
  }
  // add slash if needed
  if (aEnd != '/' && bStart != '/') {
    return a + '/' + b;
  }
  return a + b;
}
