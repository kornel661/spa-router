/*
 *  Web Router - dart
 *  Copyright (c) 2015 Kornel Maczyński, pjv, Erik Ringsmuth. For other contributors, see Github.
 */

import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'package:core_elements/core_animated_pages.dart';
import 'package:core_elements/core_ajax_dart.dart';
import 'package:template_binding/template_binding.dart';

import 'package:web_router/web_route.dart';
import 'package:web_router/src/routeUri.dart';
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
  @published bool shadow = false;
  /// typecast="auto|string"
  /// If string then even 123 will be passed as a string '123'?
  @published String typecast = "auto";
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
  /// CoreAjax element for on-demand retrieving of route's elements.
  CoreAjax _ajax;
  /// Subscription of popstate events (for address change monitoring).
  StreamSubscription<PopStateEvent> _popStateSubscription;
  /// Records URIs imported via core-ajax.
  Map<String, bool> _importedURIs = {};

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
    if (!_isInitialized || !animated) {
      super.append(node);
    } else {
      _coreAnimatedPages.append(node);
    }
    if (node is WebRoute) {
      node.router = this;
      routes.add(node);
    }
    return this;
  }

  @override
  void ready() {
    super.ready();
    _ajax = $['ajax'];
  }

  /// Initialize the router: core-animated-pages and listen for change events.
  void initialize() {
    if (_isInitialized) {
      return;
    }
    _isInitialized = true;
    _activeUri = new RouteUri.parse(window.location.href, mode);
    routes = querySelectorAll("web-route") as List<WebRoute>;
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

      // when a transition finishes, remove the previous route's content. there is a temporary overlap where both
      // the new and old route's content is in the DOM to animate the transition.
      _coreAnimatedPages.addEventListener('core-animated-pages-transition-end',
          (Event e) => transitionAnimationEnd(_previousRoute));
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
        route.activate(url);
        return;
      }
    }

    fireEvent(WebEvent.routeNotFound, eventDetail, this);
  }

  /// Plays the core-animated-pages animation (if required) and scrolls to hash.
  void playAnimation() {
    // animate the transition if core-animated-pages are being used
    if (animated) {
      _coreAnimatedPages.selected = _activeRoute.path;
      // TODO(km): after animation finishes clear invisible routes & scroll to hash
    } else {
      activeRoute.scrollToHash();
    }
  }
}

/*---------------------------------------------------------------------------*/

/// Import and activate a custom element or template.
void importAndActivate(WebRouter router, String importUri, WebRoute route,
    RouteUri url, Map<String, Object> eventDetail) {
  Element contentHtml;

  pageLoadedCallback(CustomEvent e, WebRouter router, Element contentHtml,
      String importUri, WebRoute route, RouteUri url,
      Map<String, Object> eventDetail) {
    final String content = e.detail['response'];

    if (route.active) {
      route.setContent(content, _nodeValidator);
      contentHtml = route.getContentElement();
      print("imported");
    }

    activateImport(router, contentHtml, importUri, route, url, eventDetail);
  }

  onError(Event e) {
    print("Error: could not find/load page.");
  }

  if (!router._importedURIs.containsKey(importUri)) {
    //TODO
    // hasn't been imported yet
    router._importedURIs[importUri] = true;
    //route.addEventListener('lazy-loaded', pageLoadedCallback);
    router._ajax.url = route.imp;
    router._ajax.onCoreResponse.first.then(
        (CustomEvent e) => pageLoadedCallback(
            e, router, contentHtml, importUri, route, url, eventDetail));
    router._ajax.onError.first.then(onError);
    router._ajax.go();
  } else {
    // previously imported. this is an async operation and may not be complete yet.
    if (router._ajax.loading) {
      // just wait longer
    } else {
      contentHtml = route.getContentElement();
      activateImport(router, contentHtml, importUri, route, url, eventDetail);
    }
  }
}

/// Activate the imported custom element or template.
void activateImport(WebRouter router, Element contentHtml, String importUri,
    WebRoute route, RouteUri url, Map<String, Object> eventDetail) {
  // make sure the user didn't navigate to a different route while it loaded
  if (route.active) {
    if (route.template) {
      // template
      activeTemplate(router, contentHtml.querySelector('template'), route, url,
          eventDetail);
    } else {
      // custom element
      String elementName;
      if (route.elem != null) {
        elementName = route.elem;
      } else {
        elementName = importUri.split('/').last.replaceAll(
            '.html', ''); //TODO: add transform for _ to -.
      }
      activateCustomElement(router, elementName, route, url, eventDetail);
    }
  }
}

/// Creates the custom element, binds the data to it and then activates it.
void activateCustomElement(WebRouter router, String elementName, WebRoute route,
    RouteUri url, Map<String, Object> eventDetail) {
  Element customElement = document.createElement(elementName);
  Map<String, String> model = createModel(router, route, url, eventDetail);
  customElement.attributes.addAll(
      model); //TODO: router (from bindRouter) is not a String, so bindRouter is not working yet.
  //for (String item in model.keys){
  //customElement.bindProperty(#router, router);
  //}
  //for (String item in model.keys){
  //customElement.dataset = model;
  //}
  activeElement(router, customElement, url, eventDetail);
}

/// Creates an instance of the template.
void activeTemplate(WebRouter router, TemplateElement template, WebRoute route,
    RouteUri url, Map eventDetail) {
  DocumentFragment templateInstance;
  //TODO: inline template and its binding seems not to be working always yet, for example when app-router itself is contained in a (auto-binding) template.

  Map<String, String> model = createModel(router, route, url, eventDetail);
//	if (model != {}) {//Has to be auto-binding template then
//		//// template.createInstance(model) is a Polymer method that binds a model to a template and also fixes
//		//// https://github.com/erikringsmuth/app-router/issues/19
//		//print("Using auto-binding template in app-router.");
//		templateInstance = (template as AutoBindingElement).createInstance(model);//TODO: Not working yet
//		////templateInstance = templateBindFallback(template).createInstance(model: model);
//		////template.model = toObservable(model);//
//		////templateBind(template).model = toObservable(model);
//		////templateInstance = template;
//	} else {
//		templateInstance = document.importNode(template.content, true);
//	}
  //TODO(km): check if it works
  templateInstance = templateBind(template).createInstance(model);
  activeElement(router, templateInstance, url, eventDetail);
}

/// Replaces the active route's content with the new element.
void activeElement(WebRouter router, Node element, RouteUri url,
    Map<String, Object> eventDetail) {
  // core-animated-pages temporarily needs the old and new route in the DOM at the same time to animate the transition,
  // otherwise we can remove the old route's content right away.
  // UNLESS
  // if the route we're navigating to matches the same app-route (ex: path="/article/:id" navigating from /article/0 to
  // /article/1), then we have to simply replace the route's content instead of animating a transition.
  if (!router.animated || eventDetail['route'] == eventDetail['oldRoute']) {
    removeRouteContent(router._previousRoute);
  }

  // add the new content
  router._activeRoute.append(element);

  // animate the transition if core-animated-pages are being used
  if (router.animated) {
    router._coreAnimatedPages.selected = router._activeRoute.path;

    // we already wired up transitionAnimationEnd() in init()

    // use to check if the previous route has finished animating before being removed
    if (router._previousRoute != null) {
      router._previousRoute.transitionAnimationInProgress = true;
    }
  }

  // scroll to the URL hash if it's present
  if (url.hash != null && !router.animated) {
    scrollToHash(url.hash);
  }

  fireEvent('activate-route-end', eventDetail, router);
  fireEvent('activate-route-end', eventDetail, eventDetail['route']);
}

/// Call when the previousRoute has finished the transition animation out.
void transitionAnimationEnd(WebRoute previousRoute) {
  if (previousRoute != null) {
    previousRoute.transitionAnimationInProgress = false;
    removeRouteContent(previousRoute);
  }
}

/// Remove the route's content (but not the <template> if it exists).
void removeRouteContent(WebRoute route) {
  if (route != null) {
    List<Element> newChildren = [];
    for (Element node in route.children) {
      if (node is TemplateElement) {
        //if (node.tagName == 'TEMPLATE') {
        newChildren.add(node);
      }
    }
    route.children = newChildren;
  }
}

class _TrusingNodeValidator implements NodeValidator {
  @override
  bool allowsAttribute(Element element, String attributeName, String value) =>
      true;

  @override
  bool allowsElement(Element element) => true;
}

_TrusingNodeValidator _nodeValidator = new _TrusingNodeValidator();
