/*
 *  Web Router - dart
 *  Copyright (c) 2015 Kornel Maczyński, pjv, Erik Ringsmuth. For other contributors, see Github.
 */

import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'package:template_binding/template_binding.dart';

import 'package:web_router/web_router.dart';
import 'package:web_router/src/routeUri.dart';
import 'package:web_router/src/events.dart';

/// web-route is an element describing a route within a web-router element.
/// Some syntax:
/// <app-route path="/path" [imp="/page/cust-elem.html"] [elem="cust-el"] [template] [regex] [bindRouter]></app-route>
@CustomTag('web-route')
class WebRoute extends PolymerElement with Observable {
  /// Path of the route.
  @published String path = "/";
  /// Path to the implementation of the element to be shown.
  @published String imp;
  /// Name of the element to be shown.
  @published String elem;
  /// If not empty the route redirects there.
  @published String redirect;
  /// Is it an inline template?
  @published bool template = false;
  /// Is the path a regular expression?
  @published bool regex = false;
  /// Is transition animation in progress?
  bool transitionAnimationInProgress = false;
  /// Is the route active?
  @published bool active = false;
  /// Whether to bind the router to the element.
  @published bool bindRouter;

  /// Route's router. (Set by the router during initialization.)
  WebRouter router;

  ContentElement _contentElem;
  TemplateElement _templateElem;
  RouteUri uri;

  @override
  WebRoute.created() : super.created();

  @override
  void ready() {
    super.ready();
    _contentElem = querySelector("content");
    if (template) {
      Element elem = _contentElem.querySelector("template");
      if (elem is TemplateElement) {
        _templateElem = elem;
      } else {
        print("web-route with `template=true` couldn't find its template");
      }
    }
    //print("ready: path ${path}!\n");
  }

  @override
  void remove() {
    if (router != null) {
      router.routes.remove(this);
      router = null;
    }
    super.remove();
  }

  @override
  String toString() =>
      "web-route (path: $path, imp: $imp, elem: $elem, template: $template, regex: $regex, redirect: $redirect, transitionAnimationInProgress: $transitionAnimationInProgress, active: $active, bindRouter: $bindRouter)";

  /// Sets the content of the route.
  /// TODO
  void setContent(String content, NodeValidator validator) {
    _contentElem.setInnerHtml(content, validator: validator);
  }

  /// Returns the <content> element of the route.
  /// TODO
  ContentElement getContentElement() {
    return _contentElem;
  }

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
    if (redirect != null) {
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
    if (!router.animated) {
      router.previousRoute.clearContent();
    } else {
      // TODO(km): arrange to clear the previous route when animation ends
    }

    if (imp != null) {
      // import custom element or template
      //importAndActivate(this, route.imp, route, url, eventDetail);
    } else if (elem != null) {
      // pre-loaded custom element
      Element customElem = document.createElement(elem);
			customElem.attributes.addAll(model);
			append(customElem);
    } else if (_templateElem != null) {
      // inline template
      append(templateBind(_templateElem).createInstance(model));
    }
    router.playAnimation();
  }

  /// Returns model for the route's element (for binding).
  Map<String, Object> get model {
    Map<String, Object> model = new Map<String, Object>();
    if (bindRouter != null || router.bindRouter != null) {
      model['router'] = router;
    }
    if (uri == null) {
      print("web-route: can't create model, _uri==null");
      return model;
    }
    model['uri'] = uri;
    // regular expressions can't have path variables
    if (!regex) {
      // example urlPathSegments = ['', example', 'path']
      List<String> urlPathSegments = uri.path.split('/');

      // example routePathSegments = ['', 'example', '*']
      List<String> routePathSegments = path.split('/');

      // get path variables
      // urlPath '/customer/123'
      // routePath '/customer/:id'
      // parses id = '123'
      for (int index = 0; index < routePathSegments.length; index++) {
        String routeSegment = routePathSegments[index];
        if (routeSegment.startsWith(':')) {
          model[routeSegment.substring(1)] = urlPathSegments[index];
        }
      }
    }
    List<String> queryParameters = [];
    if (uri.search.length > 0) {
      queryParameters = uri.search.substring(1).split('&');
    }
    // split() on an empty string returns ['']
    if (queryParameters.length == 1 && queryParameters[0] == '') {
      queryParameters = [];
    }
    for (int i = 0; i < queryParameters.length; i++) {
      List<String> queryParameterParts = queryParameters[i].split('=');
      if (queryParameterParts.length > 1) {
        model[queryParameterParts[0]] =
            queryParameterParts.sublist(1).join('=');
      }
    }
    return model;
  }

  /// Scrolls to the element with id="hash" or name="hash".
  /// TODO(km): test & check
  void scrollToHash() {
    String hash = uri.hash;
    if (hash == null || hash == '') return;

    void delayedScrollToHash() {
      Element hashElement = document.querySelector('html /deep/ ' + hash);
      if (hashElement == null) {
        hashElement = document
            .querySelector('html /deep/ [name="' + hash.substring(1) + '"]');
      }
      if (hashElement != null) {
        hashElement.scrollIntoView(ScrollAlignment.TOP);
      }
    }
    // TODO(km): is it working/necessary? or maybe scheduleMicrotask()?
    new Future(delayedScrollToHash);
  }
}
