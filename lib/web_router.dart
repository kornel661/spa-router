/*
 *  Web Router - dart
 *  Copyright (c) 2015 Kornel Maczyński, pjv, Erik Ringsmuth. For other contributors, see Github.
 */

import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'package:core_elements/core_animated_pages.dart';

import 'package:web_router/web_route.dart';
import 'package:web_router/src/routeuri.dart';
import 'package:web_router/src/events.dart';

/// web-router is a router element.
/// Example usage:
/// 	<web-router [init="auto|manual"] [mode="hash|pushstate"] [trailingSlash="strict|ignore"] [shadow]></app-router>
/// 	<web-router animated transitions="hero-transition cross-fade">
@CustomTag('web-router')
class WebRouter extends PolymerElement {

  /// init="auto|manual"
  /// If manual one has to initialize the router manually:
  /// 	document.querySelector('app-router').initialize();
  @published String init = "auto";
  /// mode="hash|pushstate"
  @published String mode = "hash";
  /// trailingSlash="strict|ignore"
  /// If ignore then '/home' matches '/home/' as well.
  @published String trailingSlash = "strict";
  /// Whether to use Polymer's core-animated-pages for transitions.
  @published bool animated = false;
  /// Which transitions of the core-animated-pages to use.
  /// E.g., transitions="hero-transition cross-fade"
  @published String transitions = "";
  @published bool bindRouter;

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

  RouteUri get activeUri => _activeUri;
  WebRoute get activeRoute => _activeRoute;
  set activeRoute(WebRoute r) {
    if (animated && _previousRoute != null) {
      // make sure that the content is cleared even if there was an animation in progress
      _previousRoute.clearContent();
    }
    _previousRoute = _activeRoute;
    _activeRoute = r;
  }
  WebRoute get previousRoute => _previousRoute;

  /// CoreAnimatedPages element.
  CoreAnimatedPages _coreAnimatedPages;
  /// Subscription of popstate events (for address change monitoring).
  StreamSubscription<PopStateEvent> _popStateSubscription;

  @override
  WebRouter.created() : super.created();

  @override
  void domReady() {
    super.domReady();
    if (init != "manual") {
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
      node.router = this;
      routes.add(node);
    }
    return node;
  }

  /// Initialize the router: core-animated-pages and listen for change events.
  void initialize() {
    if (_isInitialized) {
      return;
    }
    _isInitialized = true;
    //_activeUri = new RouteUri.parse(window.location.href, mode);
    routes = this.querySelectorAll("web-route") as List<WebRoute>;
    for (WebRoute route in routes) {
      route.router = this;
    }

    // <app-router core-animated-pages transitions="hero-transition cross-fade">
    if (animated) {
      // use shadow DOM to wrap the <web-route> elements in a <core-animated-pages> element
      // <web-router>
      //   # shadowRoot
      //   <core-animated-pages>
      //     <web-route elem="home-page">
      //       <home-page>
      //       </home-page>
      //     </web-route>
      //   </core-animated-pages>
      // </web-router>

      _coreAnimatedPages = new CoreAnimatedPages();
      for (WebRoute route in routes) {
        _coreAnimatedPages.append(route);
      }

      // don't know why it needs to be static, but absolute doesn't display the page
      //coreAnimatedPages.style.position = 'static';

      // toggle the selected page using selected="path" instead of selected="integer"
      _coreAnimatedPages.setAttribute('valueattr', 'path');

      // pass the transitions attribute from <app-router core-animated-pages transitions="hero-transition cross-fade">
      // to <core-animated-pages transitions="hero-transition cross-fade">
      _coreAnimatedPages.setAttribute('transitions', transitions);

      // set the shadow DOM's content
      shadowRoot.append(_coreAnimatedPages);
    }

    // listen for URL change events
    _popStateSubscription =
        window.onPopState.listen((PopStateEvent e) => _update());

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
  }

  /// go(path, {replace}) - Navigate to the path. E.g.,
  ///   go('/home')
  void go(String path, {bool replace: false}) {
    if (mode != "pushstate") {
      // mode == hash
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

  /// Find the first <web-route> that matches the current URL and change the active route.
  /// Wired to PopStateEvents.
  void _update() {
    print("log: update");
    RouteUri url = new RouteUri.parse(window.location.href, mode);

    // don't load a new route if only the hash fragment changed
    if (activeUri != null &&
        url.path == activeUri.path &&
        url.search == activeUri.search &&
        url.isHashPath == activeUri.isHashPath) {
      if (activeRoute != null) {
        activeRoute.uri = url;
        if (url.hash != activeUri.hash) {
          activeRoute.scrollToHash();
        }
      }
      _activeUri = url;
      return;
    }
    _activeUri = url;

    // fire a state-change event on the web-router and return early if the user called event.preventDefault()
    Map<String, String> eventDetail = {'path': url.path};
    if (!fireEvent(WebEvent.stateChange, eventDetail, this)) {
      return;
    }

    // find the first matching route
    for (WebRoute route in routes) {
      if (route.isMatch(url, trailingSlash != "ignore")) {
        print("log: route matched");
        route.activate(url);
        return;
      }
    }
    print("log: route not found");
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
      _coreAnimatedPages.selected = _activeRoute.path;
      // TODO(km): after animation finishes clear invisible routes & scroll to hash
    } else {
      activeRoute.scrollToHash();
    }
  }
}
