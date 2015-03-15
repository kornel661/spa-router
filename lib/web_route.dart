/*
 *  Web Router - dart
 *  Copyright (c) 2015 Kornel Maczyński, pjv, Erik Ringsmuth. For other contributors, see Github.
 */

import 'package:polymer/polymer.dart';
import 'dart:html';

import 'package:web_router/web_router.dart';
import 'package:web_router/src/routeUri.dart';

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

  ContentElement _contentContainer;

  @override
  WebRoute.created() : super.created();

  @override
  void ready() {
    super.ready();
    _contentContainer = querySelector("content");
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

  /// Sets the content of the route.
  void setContent(String content, NodeValidator validator) {
    _contentContainer.setInnerHtml(content, validator: validator);
  }

  /// Returns the <content> element of the route.
  ContentElement getContentElement() {
    return _contentContainer;
  }

  /// isMatch(uri, strictSlash) test if the route's path matches the URI's path.
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
      return _testRegExString(routePath, uriPath);
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

  @override
  String toString() =>
      "web-route (path: $path, imp: $imp, elem: $elem, template: $template, regex: $regex, redirect: $redirect, transitionAnimationInProgress: $transitionAnimationInProgress, active: $active, bindRouter: $bindRouter)";
}

/// _testRegExString(pattern, value) tests if string value maches the regular
///   expression pattern.
bool _testRegExString(String pattern, String value) {
  RegExp regexp;
  try {
    regexp = new RegExp(pattern);
  } catch (e) {
    print(
        "web-route: error creating regular expression from `${pattern}`. ${e.toString()}");
  }
  return regexp.hasMatch(value);
}
