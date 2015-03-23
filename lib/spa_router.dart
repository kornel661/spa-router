/*
 * SPA router
 * Copyright (c) 2015 Kornel Maczyński, pjv, Erik Ringsmuth.
 * For other contributors, see Github.
 */
@HtmlImport('spa_router_nodart.html')
library spa_router;

import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'package:core_elements/core_animated_pages.dart';

import 'package:spa_router/spa_route.dart';
import 'package:spa_router/src/routeuri.dart';
import 'package:spa_router/src/events.dart';

/// [SpaRouter] is a class backing `<spa-router>` element.
///
/// Typically it has `<spa-route>` elements as its children. Each `<spa-route>`
/// element describes a single route, see: [SpaRoute]. Optionally, the first
/// child of `<spa-router>` may be a `<core-animation-pages>` element which will
/// be used if [animated] attribute is set. [animated] can be also used on its
/// own in which case `<core-animated-pages>` will be created by the router.
///
/// Example usage (square brackets indicate optional attributes):
/// ```
///   <spa-router
///     [manualInit]
///     [fullPaths]
///     [relaxedSlash]
///     [animated] [transitions="hero-transition cross-fade"]
///     [bindRouter]
///     [noScroll]
///     [prefix="/prefix/path"]
///     [fragSep="@@"]>
///       <spa-route ...></spa-route>
///       ...
///   </spa-router>
/// ```
///
/// Attributes [manualInit], [fullPaths], [relaxedSlash], [animated],
/// [bindRouter] and [noScroll] are boolean. [transitions] takes space-separated
/// list of transitions, [prefix] takes a path and [fragSep] takes a string.
@CustomTag('spa-router')
class SpaRouter extends PolymerElement {
  /// If manualInit is set one has to initialize the router manually:
  ///   document.querySelector('spa-router').initialize();
  @published bool manualInit = false;
  /// Use full paths for routing (default behaviour is to use hashes).
  @PublishedProperty(reflect: true)
  bool fullPaths = false;
  /// If [relaxedSlash] is set then trailing slashes are ignored during matching,
  /// i.e., '/home' matches '/home/' as well.
  @PublishedProperty(reflect: true)
  bool relaxedSlash = false;
  /// Whether to use Polymer's core-animated-pages for transitions.
  ///
  /// If the first child of the router is <core-animated-pages> then it is used
  /// for transitions (router's [transitions] attribute is ignored). This gives
  /// opportunity to configure <core-animated-pages>.
  /// Otherwise, router creates <core-animated-pages> on its own.
  @published bool animated = false;
  /// Which transitions of the core-animated-pages to use.
  /// E.g., [transitions]="hero-transition cross-fade"
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
  /// Fragment separator. In the default mode (when [fullPaths] is false)
  /// [fragSep] is a string that separates path (and query) from the fragment
  /// (hash). Defaults to '@@'. Example:
  ///     location 'xxxxx#/some/path?query1=sth##hash
  /// results in path: '/some/path', query: '?guery1=sth', fragment: '#hash'.
  /// If [fullPaths] is true [fragSep]'s value is ignored.
  @PublishedProperty(reflect: true)
  String fragSep = "@@";

  /// Is the router initialized already?
  bool _isInitialized = false;
  /// Active URL.
  RouteUri _activeUri;
  /// Previous active route.
  SpaRoute _previousRoute;
  /// Currently active route.
  SpaRoute _activeRoute;
  /// All routes.
  List<SpaRoute> routes;

  /// Currently active URL.
  RouteUri get activeUri => _activeUri;
  /// Currently active route.
  SpaRoute get activeRoute => _activeRoute;
  /// Currently active route.
  set activeRoute(SpaRoute r) {
    if (animated && _previousRoute != null) {
      // make sure that the content is cleared even if there was an animation in progress
      _previousRoute.clearContent();
    }
    _previousRoute = _activeRoute;
    _activeRoute = r;
  }
  /// Previous active route.
  SpaRoute get previousRoute => _previousRoute;

  /// CoreAnimatedPages element.
  CoreAnimatedPages _coreAnimatedPages;
  /// Subscription of popstate events (for address change monitoring).
  StreamSubscription<PopStateEvent> _popStateSubscription = null;

  @override
  SpaRouter.created() : super.created();

  @override
  void domReady() {
    super.domReady();
    if (!manualInit) {
      initialize();
    }
  }

  @override
  Node append(Node node) {
    if (!_isInitialized) {
      super.append(node);
      return node;
    }
    if (!animated) {
      super.append(node);
    } else {
      _coreAnimatedPages.append(node);
    }
    if (node is SpaRoute) {
      _prepareRoute(node, prefix);
      routes.add(node);
    }
    return node;
  }

  /// Sets [route.router] to [this] and adds prefix to [route.path].
  _prepareRoute(SpaRoute route, String pref) {
    route.router = this;
    route.path = _joinPaths(pref, route.path);
  }

  /// Initializes the router: creates core-animated-pages and listen for events.
  void initialize() {
    if (_isInitialized) {
      return;
    }
    routes = new List<SpaRoute>();
    void walk(List<Element> l, String pref) {
      for (Element route in l) {
        if (route is SpaRoute) {
          routes.add(route);
          _prepareRoute(route, pref);
          walk(route.children, route.path);
        }
      }
    }
    walk(this.children, prefix);

    if (!animated) {
      // flatten route hierarchy
      this.children.addAll(routes);
    } else {
      if (this.children.first is CoreAnimatedPages) {
        _coreAnimatedPages = this.children.first;
      } else {
        _coreAnimatedPages = new CoreAnimatedPages();
        _coreAnimatedPages.setAttribute('transitions', transitions);
      }
      // flatten route hierarchy and put them in the animated pages
      for (SpaRoute route in routes) {
        _coreAnimatedPages.append(route);
      }
      // decide which route is selected based on `path` attribute
      _coreAnimatedPages.setAttribute('valueattr', 'path');
      this.append(_coreAnimatedPages);
      // clear previous route when animation ends
      // _coreAnimatedPages.onTransitionEnd.listen(...) didn't work in Chromium
      _coreAnimatedPages.addEventListener(
          'core-animated-pages-transition-end', _transitionEndCallback);
    }
    // listen for URL change events
    _popStateSubscription =
        window.onPopState.listen((PopStateEvent e) => _update());
    // mark router as initialized
    _isInitialized = true;
    // load the web component for the current route (in [Future] to give routes
    // a chance to update their internal state (e.g., _uriMatcher)
    new Future(_update);
  }

  /// Cleans-up global event listeners.
  @override
  void detached() {
    super.detached();
    if (_popStateSubscription != null) {
      _popStateSubscription.cancel();
    }
    if (_coreAnimatedPages != null) {
      _coreAnimatedPages.removeEventListener(
          'core-animated-pages-transition-end', _transitionEndCallback);
    }
  }

  /// Navigates to [path]. E.g.,
  ///     `go('/home')`
  /// Uses window.history.pushState unless [replace]==true in which case
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

  /// Finds the first `<spa-route>` that matches the current URL and changes the active route.
  /// Wired to PopStateEvents.
  void _update() {
    RouteUri url = new RouteUri.parse(window.location.href, fullPaths, fragSep);
    // fire a address-change event on the spa-router and return early if the user
    // called event.preventDefault()
    if (!fireAddressChange(this, url.path)) {
      return;
    }
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
    // find the first matching route
    for (SpaRoute route in routes) {
      if (route.isMatch(url, !relaxedSlash)) {
        _activeUri = url;
        route.activate(url);
        return;
      }
    }
    fireRouteNotFound(this, url.path);
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

  /// Called when transition ends. Clears the previous route and scrolls.
  _transitionEndCallback(Event e) {
    if (_previousRoute != null) {
      _previousRoute.clearContent();
      _activeRoute.scrollToHash();
    }
  }

  /// Returns a stream of route-not-found events. See [fireRouteNotFound].
  ElementStream<CustomEvent> get onRouteNotFound {
    return this.on[SpaEvent.routeNotFound];
  }
  /// Returns a stream of route-activate events. See [fireRouteActivate].
  ElementStream<CustomEvent> get onRouteActivate {
    return this.on[SpaEvent.routeActivate];
  }
  /// Returns a stream of address-change events. See [fireAddressChange].
  ElementStream<CustomEvent> get onAddressChange {
    return this.on[SpaEvent.addressChange];
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
