/*
 *  Web Router - dart
 *  Copyright (c) 2015 Kornel Maczyński, pjv, Erik Ringsmuth. For other contributors, see Github.
 */

import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'package:core_elements/core_animated_pages.dart';
import 'package:web_router/web_route.dart';
import 'package:core_elements/core_ajax_dart.dart';
import 'package:template_binding/template_binding.dart';

import 'src/routeUri.dart';

Map<String, bool> _importedURIs = {};

/// web-router is a router element.
/// Example usage:
/// 	<app-router [init="auto|manual"] [mode="hash|pushstate"] [trailingSlash="strict|ignore"] [shadow]></app-router>
/// 	<app-router core_animated_pages transitions="hero-transition cross-fade">
@CustomTag('web-router')
class WebRouter extends PolymerElement {

  /// init="auto|manual"
  /// If manual one has to initialize the router manually:
  /// 	document.querySelector('app-router').init();
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
  @published bool core_animated_pages = false;
  /// Which transitions of the core-animated-pages to use.
  /// E.g., transitions="hero-transition cross-fade"
  @published String transitions = "";
  @published bool bindRouter;

  /// Is the router initilized already?
  bool _isInitialized = false;
  /// Previous active route.
  WebRoute _previousRoute;
  /// Previous active URL.
  RouteUri _previousUrl;
  /// Currently active route.
  WebRoute _activeRoute;
  /// CoreAnimatedPages element.
  CoreAnimatedPages _coreAnimatedPages;
  /// CoreAjax element for on-demand retrieving of route's elements.
  CoreAjax _ajax;
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
    _previousUrl = new RouteUri.parse(window.location.href, mode);

    // <app-router core-animated-pages transitions="hero-transition cross-fade">
    if (core_animated_pages) {
      //print('core-animated-pages');
      // use shadow DOM to wrap the <app-route> elements in a <core-animated-pages> element
      // <app-router>
      //   # shadowRoot
      //   <core-animated-pages>
      //     # content in the light DOM
      //     <app-route elem="home-page">
      //       <home-page>
      //       </home-page>
      //     </app-route>
      //   </core-animated-pages>
      // </app-router>
      //createShadowRoot();

      List<WebRoute> webRoutes =
          querySelectorAll("web-route") as List<WebRoute>;

      _coreAnimatedPages = new CoreAnimatedPages();
      for (WebRoute route in webRoutes) {
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
  void _update() {
    RouteUri url = new RouteUri.parse(window.location.href, mode);

    // don't load a new route if only the hash fragment changed
    if (url.hash != _previousUrl.hash &&
        url.path == _previousUrl.path &&
        url.search == _previousUrl.search &&
        url.isHashPath == _previousUrl.isHashPath) {
      scrollToHash(url.hash);
      return;
    }
    _previousUrl = url;

    // fire a state-change event on the app-router and return early if the user called event.preventDefault()
    Map<String, String> eventDetail = {'path': url.path};
    if (!fireEvent('state-change', eventDetail, this)) {
      return;
    }

    // find the first matching route
    List<Element> elems;
    if (core_animated_pages) {
      elems = _coreAnimatedPages.children;
    } else {
      elems = children;
    }
    for (Element route in elems) {
      if (route is WebRoute) {
        if (testRoute(route.path, url.path, trailingSlash, route.regex)) {
          activateRoute(this, route, url);
          return;
        }
      }
    }

    fireEvent('route-not-found', eventDetail, this);
  }

  /// fireEvent(type, detail, node) - Fire a new CustomEvent(type, detail) on the node
  ///
  /// listen with document.querySelector('app-router').addEventListener(type, function(event) {
  ///   event.detail, event.preventDefault()
  /// })
  bool fireEvent(String type, Object detail, Node node) {
    CustomEvent event = new CustomEvent(type,
        detail: detail, canBubble: false, cancelable: true);
    return node.dispatchEvent(event);
  }
}

/*---------------------------------------------------------------------------*/

/// Activate the route
void activateRoute(WebRouter router, WebRoute route, RouteUri url) {
  if (route.redirect != null) {
    router.go(route.redirect, replace: true);
    return;
  }

  Map<String, Object> eventDetail = {
    'path': url.path,
    'route': route,
    'oldRoute': router._activeRoute
  };
  if (!router.fireEvent('activate-route-start', eventDetail, router)) {
    //TODO: are dashes allowed in Polymer event names?
    return;
  }
  if (!router.fireEvent('activate-route-start', eventDetail, route)) {
    return;
  }

  // update the references to the activeRoute and previousRoute. if you switch between routes quickly you may go to a
  // new route before the previous route's transition animation has completed. if that's the case we need to remove
  // the previous route's content before we replace the reference to the previous route.
  if (router._previousRoute != null &&
      router._previousRoute.transitionAnimationInProgress) {
    transitionAnimationEnd(router._previousRoute);
  }
  if (router._activeRoute != null) {
    router._activeRoute.active = false;
  }
  router._previousRoute = router._activeRoute;
  router._activeRoute = route;
  router._activeRoute.active = true;

  // import custom element or template
  if (route.imp != null) {
    importAndActivate(router, route.imp, route, url, eventDetail);
  }
  // pre-loaded custom element
  else if (route.elem != null) {
    activateCustomElement(router, route.elem, route, url, eventDetail);
  }
  // inline template
  else if (route.children.length != 0 &&
      route.children.first != null &&
      route.children.first.tagName == 'TEMPLATE') {
    activeTemplate(router, route.children.first, route, url, eventDetail);
  }
}

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
      contentHtml = route.getContent();
      print("imported");
    }

    activateImport(router, contentHtml, importUri, route, url, eventDetail);
  }

  onError(Event e) {
    print("Error: could not find/load page.");
  }

  if (!_importedURIs.containsKey(importUri)) {
    //TODO
    // hasn't been imported yet
    _importedURIs[importUri] = true;
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
      contentHtml = route.getContent();
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
      activeTemplate(router,
          contentHtml.querySelector('template'), route, url, eventDetail);
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
  //FIXME(km): check if it works
  templateInstance = templateBind(template).createInstance(model);
  activeElement(router, templateInstance, url, eventDetail);
}

/// Creates the route's model.
Map<String, Object> createModel(WebRouter router, WebRoute route, RouteUri url,
    Map<String, Object> eventDetail) {
  Map<String, Object> model = routeArguments(route.getAttribute('path'),
      url.path, url.search, route.regex, router.typecast == 'auto');
  if (route.bindRouter != null || router.bindRouter != null) {
    model['router'] = router;
    print("router.templateInstance.model: ${router.templateInstance.model}");
  }
  eventDetail['model'] = model;
  router.fireEvent('before-data-binding', eventDetail, router);
  router.fireEvent('before-data-binding', eventDetail, eventDetail['route']);
  return eventDetail['model'];
}

/// Replaces the active route's content with the new element.
void activeElement(WebRouter router, Node element, RouteUri url,
    Map<String, Object> eventDetail) {
  // core-animated-pages temporarily needs the old and new route in the DOM at the same time to animate the transition,
  // otherwise we can remove the old route's content right away.
  // UNLESS
  // if the route we're navigating to matches the same app-route (ex: path="/article/:id" navigating from /article/0 to
  // /article/1), then we have to simply replace the route's content instead of animating a transition.
  if (!router.core_animated_pages ||
      eventDetail['route'] == eventDetail['oldRoute']) {
    removeRouteContent(router._previousRoute);
  }

  // add the new content
  router._activeRoute.append(element);

  // animate the transition if core-animated-pages are being used
  if (router.core_animated_pages) {
    router._coreAnimatedPages.selected = router._activeRoute.path;

    // we already wired up transitionAnimationEnd() in init()

    // use to check if the previous route has finished animating before being removed
    if (router._previousRoute != null) {
      router._previousRoute.transitionAnimationInProgress = true;
    }
  }

  // scroll to the URL hash if it's present
  if (url.hash != null && !router.core_animated_pages) {
    scrollToHash(url.hash);
  }

  router.fireEvent('activate-route-end', eventDetail, router);
  router.fireEvent('activate-route-end', eventDetail, eventDetail['route']);
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

/// Scroll to the element with id="hash" or name="hash".
void scrollToHash(String hash) {
  if (hash == null || hash == '') return;

  // wait for the browser's scrolling to finish before we scroll to the hash
  // ex: http://example.com/#/page1#middle
  // the browser will scroll to an element with id or name `/page1#middle` when the page finishes loading. if it doesn't exist
  // it will scroll to the top of the page. let the browser finish the current event loop and scroll to the top of the page
  // before we scroll to the element with id or name `middle`.

  void onTimerScrollToHash() {
    Element hashElement = document.querySelector('html /deep/ ' + hash);
    if (hashElement == null) {
      hashElement = document
          .querySelector('html /deep/ [name="' + hash.substring(1) + '"]');
    }
    if (hashElement != null /*&& hashElement.scrollIntoView*/) {
      //TODO
      hashElement.scrollIntoView(ScrollAlignment.TOP);
    }
  }

  new Timer(new Duration(milliseconds: 0), onTimerScrollToHash); //TODO
}

/// testRoute(routePath, urlPath, trailingSlashOption, isRegExp) - Test if the route's path matches the URL's path
///
/// Example routePath: '/example/*'
/// Example urlPath = '/example/path'
bool testRoute(String routePath, String urlPath, String trailingSlashOption,
    bool isRegExp) {
  // this algorithm tries to fail or succeed as quickly as possible for the most common cases

  // handle trailing slashes (options: strict (default), ignore)
  if (trailingSlashOption == 'ignore') {
    // remove trailing / from the route path and URL path
    if (urlPath.endsWith('/')) {
      urlPath = urlPath.substring(0, urlPath.length - 1); //TODO
    }
    if (routePath.endsWith('/') && !isRegExp) {
      routePath = routePath.substring(0, routePath.length - 1);
    }
  }

  // test regular expressions
  if (isRegExp) {
    return testRegExString(routePath, urlPath);
  }

  // if the urlPath is an exact match or '*' then the route is a match
  if (routePath == urlPath || routePath == '*') {
    return true;
  }

  // look for wildcards
  if (routePath.indexOf('*') == -1 && routePath.indexOf(':') == -1) {
    // no wildcards and we already made sure it wasn't an exact match so the test fails
    return false;
  }

  // example urlPathSegments = ['', example', 'path']
  List<String> urlPathSegments = urlPath.split('/');

  // example routePathSegments = ['', 'example', '*']
  List<String> routePathSegments = routePath.split('/');

  // there must be the same number of path segments or it isn't a match
  if (urlPathSegments.length != routePathSegments.length) {
    return false;
  }

  // check equality of each path segment
  for (int i = 0; i < routePathSegments.length; i++) {
    // the path segments must be equal, be a wildcard segment '*', or be a path parameter like ':id'
    String routeSegment = routePathSegments[i];
    if (routeSegment != urlPathSegments[i] &&
        routeSegment != '*' &&
        !routeSegment.startsWith(':')) {
      // the path segment wasn't the same string and it wasn't a wildcard or parameter
      return false;
    }
  }

  // nothing failed. the route matches the URL.
  return true;
}

/// routeArguments(routePath, urlPath, search, isRegExp) - Gets the path variables and query parameter values from the URL.
Map routeArguments(String routePath, String urlPath, String search,
    bool isRegExp, bool autoTypecast) {
  Map<String, String> args = {};

  // regular expressions can't have path variables
  if (!isRegExp) {
    // example urlPathSegments = ['', example', 'path']
    List<String> urlPathSegments = urlPath.split('/');

    // example routePathSegments = ['', 'example', '*']
    List<String> routePathSegments = routePath.split('/');

    // get path variables
    // urlPath '/customer/123'
    // routePath '/customer/:id'
    // parses id = '123'
    for (int index = 0; index < routePathSegments.length; index++) {
      String routeSegment = routePathSegments[index];
      if (routeSegment.startsWith(':')) {
        args[routeSegment.substring(1)] = urlPathSegments[index];
      }
    }
  }

  List<String> queryParameters = [];
  if (search.length > 0) {
    queryParameters = search.substring(1).split('&');
  }
  // split() on an empty string has a strange behavior of returning [''] instead of []
  if (queryParameters.length == 1 && queryParameters[0] == '') {
    queryParameters = [];
  }
  for (int i = 0; i < queryParameters.length; i++) {
    String queryParameter = queryParameters[i];
    List<String> queryParameterParts = queryParameter.split('=');
    args[queryParameterParts[0]] =
        queryParameterParts.sublist(1).join('='); //TODO
  }

  if (autoTypecast) {
    // parse the arguments into unescaped strings, numbers, or booleans
    for (String arg in args.keys) {
      args[arg] = typecast(args[arg]);
    }
  }

  return args;
}

/// typecast(value) - Typecast the string value to an unescaped string, number, or boolean.
String typecast(String value) {
  // bool
  if (value == 'true') {
    return 'true';
  }
  if (value == 'false') {
    return 'false';
  }

  // number
  if (value != '' && !value.startsWith('0')) {
    int number = int.parse(value, onError: (string) => 0);
    if (number != 0) {
      return number.toString();
    }
  }

  // string
  return Uri.decodeComponent(value);
}

/// testRegExString(pattern, value) - Parse HTML attribute path="/^\/\w+\/\d+$/i" to a regular
/// expression `new RegExp('^\/\w+\/\d+$', 'i')` and test against it.
///
/// note that 'i' is the only valid option. global 'g', multiline 'm', and sticky 'y' won't be valid matchers for a path.
bool testRegExString(String pattern, String value) {
  if (!pattern.startsWith('/')) {
    // must start with a slash
    return false;
  }
  pattern = pattern.substring(1);
  var options = '';
  if (pattern.endsWith('/')) {
    pattern = pattern.substring(0, -1);
  } else if (pattern.endsWith('/i')) {
    pattern = pattern.substring(0, -2);
    options = 'i';
  } else {
    // must end with a slash followed by zero or more options
    return false;
  }
  return new RegExp(r"${pattern}").hasMatch(value); //TODO
}

class _TrusingNodeValidator implements NodeValidator {
  @override
  bool allowsAttribute(Element element, String attributeName, String value) =>
      true;

  @override
  bool allowsElement(Element element) => true;
}

_TrusingNodeValidator _nodeValidator = new _TrusingNodeValidator();
