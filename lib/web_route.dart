/*
 *  Web Router - dart
 *  Copyright (c) 2015 Kornel Maczyński, pjv, Erik Ringsmuth. For other contributors, see Github.
 */
@HtmlImport('package:/web_router/web_route.html')
library web_route;

import 'package:polymer/polymer.dart';
import 'package:core_elements/core_ajax_dart.dart';
import 'dart:html';
import 'dart:async';
import 'package:template_binding/template_binding.dart';

import 'package:web_router/web_router.dart';
import 'package:web_router/src/routeuri.dart';
import 'package:web_router/src/events.dart';

/// <web-route> is an element describing a route within a web-router element.
/// Some syntax (square brackets indicate optional attributes):
/// ```
///   <web-route
///     [path="/route/path"]
///     [impl="/path/to/custom-element.html"]
///     [elem="custom-element-name"]
///     [redirect="/path/to/redirect/to"]
///     [regex] [bindRouter]
///     [uriAttr="url"]
///     [noScroll]
///     [queryParams="param1 param2"]>
///   </app-route>
/// ```
/// String attributes default to empty string with notable exceptions path="/"
/// and queryParams=null. Boolean attributes default to false.
@CustomTag('web-route')
class WebRoute extends PolymerElement with Observable {
  /// Path of the route.
  @published String path = "/";
  /// Path to the implementation of the element to be shown.
  @published String impl = "";
  /// Name of the element to be shown.
  @published String elem = "";
  /// If not empty the route redirects there.
  @published String redirect = "";
  /// Is the path a regular expression?
  @published bool regex = false;
  /// Whether to bind the router to the route's CustomElement.
  /// The <custom-element> must be supported by Dart class with public non-final
  /// field `router` of type WebRouter. The field will be set to route's router
  /// when the element is instantiated.
  @published bool bindRouter = false;
  /// If uriAttr="nameA" is set then nameA attribute of the route's element
  /// will be set to the route's URI.
  @published String uriAttr = "";
  /// Don't use scrolling to hash.
  @published bool noScroll = false;
  /// If set it specifies a space-separated list of query parameters, e.g.,
  ///   `param1 param2` for `?param1=val1&param2=val...`
  /// that will be forwarded (as attributes) to the route's element.
  /// If not set then all parameters are forwarded.
  @published String queryParams = null;

  /// Route's router. (Set by the router during initialization.)
  WebRouter router;
  /// Route's current uri.
  RouteUri uri;

  ContentElement _contentElem;
  TemplateElement _templateElem;
  /// CoreAjax element for on-demand retrieving of route's elements.
  CoreAjax _ajax;
  /// Was the _ajax.go() executed?
  bool _ajaxLoaded = false;

  @override
  WebRoute.created() : super.created();

  @override
  void ready() {
    super.ready();
    _contentElem = shadowRoot.querySelector("content");
    _ajax = $['ajax'];
    _ajax.onCoreResponse.first.then((CustomEvent e) {
      // add definition of elem
      _contentElem.setInnerHtml(e.detail['response'],
          validator: _nodeValidator);
      // add elem (if the route is still active)
      if (router.activeRoute == this) {
        _createCustomElem();
      }
    });
    Element elem = this.querySelector("template");
    //elem = children.first;
    if (elem is TemplateElement) {
      _templateElem = elem;
    }
  }

  @override
  void remove() {
    if (router != null) {
      router.routes.remove(this);
      router = null;
    }
    clearContent();
    super.remove();
  }

  @override
  String toString() =>
      "web-route (path: $path, imp: $impl, elem: $elem, regex: $regex, redirect: $redirect, bindRouter: $bindRouter)";

  /// Clears route's content.
  void clearContent() {
    //_uri = null;
    List<Element> newChildren = [];
    if (_templateElem != null) {
      newChildren.add(_templateElem);
    }
    this.children = newChildren;
  }

  /// isMatch(uri, strictSlash) tests if the route's path matches the URI's path.
  bool isMatch(RouteUri uri, [bool strictSlash = true]) {
    String uriPath = uri.path;
    String routePath = this.path;
    if (!strictSlash) {
      // remove trailing '/'
      while (uriPath.endsWith('/')) {
        uriPath = uriPath.substring(0, uriPath.length - 1);
      }
      while (routePath.endsWith('/') && !regex) {
        routePath = routePath.substring(0, routePath.length - 1);
      }
    }

    // test regular expressions
    if (regex) {
      RegExp regexp;
      try {
        regexp = new RegExp(routePath);
        return regexp.hasMatch(uriPath);
      } catch (e) {
        print(
            "web-route: error creating regular expression from `${routePath}`. ${e.toString()}");
        return false;
      }
    }

    // if the urlPath is an exact match or '**' then the route is a match
    if (uriPath == routePath || routePath == '**') {
      return true;
    }

    // look for wildcards
    if (routePath.indexOf('*') == -1 && routePath.indexOf(':') == -1) {
      // no wildcards and we already made sure it wasn't an exact match so the test fails
      return false;
    }

    // example urlPathSegments = ['', example', 'path']
    List<String> uriPathSegments = uriPath.split('/');

    // example routePathSegments = ['', 'example', '*']
    List<String> routePathSegments = routePath.split('/');

    // there must be the same number of path segments or it isn't a match
    if (uriPathSegments.length != routePathSegments.length) {
      return false;
    }

    // check equality of each path segment
    for (int i = 0; i < routePathSegments.length; i++) {
      // the path segments must be equal, be a wildcard segment '*', or be a path parameter like ':id'
      String routeSegment = routePathSegments[i];
      if (routeSegment != uriPathSegments[i] &&
          routeSegment != '*' &&
          !routeSegment.startsWith(':')) {
        // the path segment wasn't the same string and it wasn't a wildcard or parameter
        return false;
      }
    }

    // nothing failed, the route matches the URL.
    return true;
  }

  /// Activate the route
  void activate(RouteUri url) {
    if (redirect != null && redirect != "") {
      router.go(redirect, replace: true);
      return;
    }
    uri = url;
    Map<String, Object> eventDetail = {
      'path': url.path,
      'route': this,
      'oldRoute': router.activeRoute
    };
    if (!fireEvent(WebEvent.activateRouteStart, eventDetail, this)) {
      return;
    }
    if (!fireEvent(WebEvent.activateRouteStart, eventDetail, router)) {
      return;
    }

    router.activeRoute = this;
    if (!router.animated && router.previousRoute != null) {
      router.previousRoute.clearContent();
    } else {
      // TODO(km): arrange to clear the previous route when animation ends
    }
    if (impl != null && impl != "") {
      // discern the name of the element to create
      if (elem == null || elem == "") {
        elem =
            impl.split('/').last.replaceAll('.html', '').replaceAll('_', '-');
      }
      // import custom element or template
      if (!_ajaxLoaded) {
        _ajaxLoaded = true;
        // now download definition of elem and add it
        _ajax.go();
      } else {
        // definition is loaded already
        _createCustomElem();
      }
    } else if (elem != null && elem != "") {
      // pre-loaded custom element
      _createCustomElem();
    } else if (_templateElem != null) {
      // inline template
      append(templateBind(_templateElem).createInstance(model));
    }
    router.playAnimation();
  }

  /// Creates custom element elem. Definition of elem needs to be loaded already.
  void _createCustomElem() {
    Element customElem = document.createElement(elem);
    customElem.attributes.addAll(model);
    if (bindRouter) {
      // bind router to customElement.router (if it exists)
      try {
        (customElem as dynamic).router = router;
      } catch (e) {
        window.console.error("""web-route: error binding router
           (if bindRouter is enabled the route's element must be supported by
           Dart class with public non-final field `router` of type WebRouter):
           ${e}""");
      }
    }
    append(customElem);
  }

  /// Returns model for the route's element (for binding).
  Map<String, String> get model {
    Map<String, String> model = new Map<String, String>();
    if (uri == null) {
      window.console.error("web-route: can't create model, _uri==null.");
      return model;
    }
    if (uriAttr != null && uriAttr != "") {
      model[uriAttr] = uri.toString();
    }
    // regular expressions can't have path variables
    if (!regex) {
      // example urlPathSegments = ['', example', 'path']
      List<String> uriSegments = uri.path.split('/');
      List<String> routeSegments = path.split('/');
      // get path variables
      // urlPath '/customer/123'
      // routePath '/customer/:id'
      // parses id = '123'
      for (int i = 0; i < routeSegments.length; i++) {
        String rSegment = routeSegments[i];
        if (rSegment.startsWith(':')) {
          model[rSegment.substring(1)] = Uri.decodeComponent(uriSegments[i]);
        }
      }
    }
    // extract query parameters
    List<String> qParams = [];
    if (uri.search.length > 1) {
      qParams = uri.search.substring(1).split('&');
      for (String qParam in qParams) {
        List<String> qParamParts = qParam.split('=');
        if (qParamParts.length > 1) {
          List<String> allowedParams;
          if (this.queryParams != null) {
            allowedParams = queryParams.split(' ');
          }
          if (this.queryParams == null ||
              allowedParams.contains(qParamParts[0])) {
            model[qParamParts[0]] =
                Uri.decodeQueryComponent(qParamParts.sublist(1).join('='));
          }
        }
      }
    }
    return model;
  }

  /// Scrolls to the element with id="hash" or name="hash".
  void scrollToHash() {
    if (noScroll || router.noScroll) {
      return;
    }
    String hash = uri.hash;
    if (hash == null || hash == '') return;

    void delayedScroll() {
      Element hashElement = document.querySelector('html /deep/ ' + hash);
      if (hashElement == null) {
        hashElement = document
            .querySelector('html /deep/ [name="' + hash.substring(1) + '"]');
      }
      if (hashElement != null) {
        hashElement.scrollIntoView(ScrollAlignment.TOP);
      }
    }
    // TODO(km): is it working? or maybe scheduleMicrotask()?
    new Future(delayedScroll);
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
