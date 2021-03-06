/*
 * SPA router
 * Copyright (c) 2015 Kornel Maczyński, pjv, Erik Ringsmuth.
 * For other contributors, see Github.
 */
@HtmlImport('spa_route_nodart.html')
library spa_route;

import 'package:polymer/polymer.dart';
import 'package:core_elements/core_ajax_dart.dart';
import 'dart:html';
import 'dart:async';
import 'package:template_binding/template_binding.dart';

import 'package:spa_router/spa_router.dart';
import 'package:spa_router/src/routeuri.dart';
import 'package:spa_router/src/events.dart';
import 'package:spa_router/src/uri_matcher.dart';

/// [SpaRoute] is a class backing `<spa-route>` element. `<spa-route>` describes
/// a route within [SpaRouter]'s `<spa-router>` element.
///
/// Typically `<spa-route>` is a child of `<spa-router>` or another
/// `<spa-route>` element (it's called subroute in this case). Being a subroute
/// is equivalent to being a next sibling of the super-route with path prefixed
/// with super-route's path.
///
/// The first `<template>` element among route's children is used to instatiate
/// route's content when neither [elem] nor [impl] are set.
///
/// Example usage (square brackets indicate optional attributes):
/// ```
///   <spa-route
///     [path="/route/path"]
///     [impl="/path/to/custom_element.html"]
///     [elem="custom-element-name"]
///     [redirect="/path/to/redirect/to"]
///     [regex] [bindRouter]
///     [uriAttr="url"]
///     [noScroll]
///     [queryParams="param1 param2"]>
///   </spa-route>
/// ```
/// String attributes [impl], [elem], [redirect] and [uriAttr] default to empty
/// strings but [path]="/" and [queryParams]="*". Boolean attributes [regex],
/// [bindRouter] and [noScroll] default to false.
///
/// * If neither [impl] nor [elem] are set then the route instantiates its child
///   template (if it exists) on activation.
/// * If [impl] is set, e.g.,
///     `impl="/path/to/custom_element.html"`
///   then "/path/to/custom_element.html" is fetched and a new element is created.
///   The element's name is `custom-element` (the last segment of the uri without
///   `.html` and with non-alpabetical characters replaced by dashes or, if
///   [elem] is set, it is just [elem].
/// * If just [elem] is set (e.g., `elem="my-element"`) then, upon route's
///   activation, new [elem] element is created (e.g., `<my-element>`).
@CustomTag('spa-route')
class SpaRoute extends PolymerElement {
  /// Path of the route. If parent router's prefix is set it is added to the path.
  ///
  /// Unless [regex] is set:
  /// * Path has segments separated by slashes `/`.
  /// * Segment starting with a colon `:` matches a single segment and adds a
  ///   binding, e.g., `/:name/edit` matches uri `/Joe/edit` and adds binding
  ///   name=Joe if route's element is a template or sets `name` attribute of
  ///   the route's element to `Joe` otherwise.
  /// * `*` matches a single segment (doesn't add any bindings).
  /// * Path may end with `**` segment which matches any number of segments.
  /// * All other segments must match literally.
  /// * The query string (starting at `?`) and hash (starting at `#`) of the uri
  ///   are discarded for the purpose of matching. Query adds bindings, hash
  ///   controls scrolling by default.
  @PublishedProperty(reflect: true)
  String path = "/";
  /// Address of the implementation of the element to be shown.
  ///
  /// The implementation will be fetched when the route is activated for the
  /// first time. Probably doesn't work with Polymer.dart see:
  ///   <https://code.google.com/p/dart/issues/detail?id=17873>
  @PublishedProperty(reflect: true)
  String impl = "";
  /// Name of the element to be shown.
  /// It's called the custom element or route's element throughout this documentation.
  @PublishedProperty(reflect: true)
  String elem = "";
  /// If not empty the route redirects there.
  @PublishedProperty(reflect: true)
  String redirect = "";
  /// If true, the [path] is interpreted as a regular expression [RegExp].
  @PublishedProperty(reflect: true)
  bool regex = false;
  /// Whether to bind the router to the route's CustomElement.
  ///
  /// The `<custom-element>` must be supported by Dart class with public non-final
  /// field `router` of type [SpaRouter]. The field will be set to route's router
  /// when the element is instantiated.
  @PublishedProperty(reflect: true)
  bool bindRouter = false;
  /// The name of the attribute to which route's uri will be bound. Doesn't
  /// have effect for templates.
  ///
  /// If `uriAttr="nameA"` is set then nameA attribute of the route's element
  /// will be set to the route's URI.
  @PublishedProperty(reflect: true)
  String uriAttr = "";
  /// Don't scroll to hash.
  @PublishedProperty(reflect: true)
  bool noScroll = false;
  /// If set it specifies a space-separated list of query parameters, e.g.,
  ///   `param1 param2` for `?param1=val1&param2=val...`
  /// that will be forwarded (as attributes) to the route's element.
  /// If set to `*` (the default) then all parameters are forwarded.
  @PublishedProperty(reflect: true)
  String queryParams = "*";

  /// Route's router. (Set by the router during initialization.)
  SpaRouter router;
  /// Route's current uri.
  RouteUri uri;

  /// [UriMatcher] for route's [path].
  UriMatcher _uriMatcher = newMatcher("/");
  /// [ContentElement] of this [SpaRoute].
  ContentElement _contentElem;
  /// [TemplateElement] of this [SpaRoute].
  TemplateElement _templateElem;
  /// [CoreAjax] element for on-demand retrieving of route's elements.
  CoreAjax _ajax;
  /// Was the _ajax.go() executed?
  bool _ajaxLoaded = false;

  @override
  SpaRoute.created() : super.created();

  /// Initializes and sets up the CoreAjax element.
  void _initializeAjax() {
    _ajaxLoaded = false;
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
  }

  /// Fired when [impl] attribute changes. Resets the CoreAjax element to fetch
  /// [impl] next time the route is activated.
  void implChanged() {
    _initializeAjax();
  }
  /// Fired when [path] attribute changes. Updates [_uriMatcher] to match URIs
  /// against [path].
  void pathChanged() {
    _uriMatcher = newMatcher(path);
  }

  @override
  void ready() {
    super.ready();
    // don't
    //   _initializeAjax();
    // it's done in the [implChanged]
    _contentElem = shadowRoot.querySelector("content");
  }

  @override
  void domReady() {
    super.domReady();
    for (Element elem in this.children) {
      if (elem is TemplateElement) {
        _templateElem = elem;
        break;
      }
    }
  }

  @override
  void remove() {
    if (router != null) {
      router.routes.remove(this);
      path = path.substring(router.prefix.length);
      router = null;
    }
    clearContent();
    super.remove();
  }

  @override
  String toString() =>
      "spa-route (path: $path, imp: $impl, elem: $elem, regex: $regex, redirect: $redirect, bindRouter: $bindRouter)";

  /// Resets route's children.
  void clearContent() {
    List<Element> newChildren = [];
    if (_templateElem != null) {
      newChildren.add(_templateElem);
    }
    this.children = newChildren;
  }

  /// Tests if the route's [path] matches the [uri]'s path.
  bool isMatch(RouteUri uri, [bool strictSlash = true]) {
    String uriPath = uri.path;
    String routePath = this.path;
    if (!strictSlash) {
      // remove trailing '/'
      while (uriPath.endsWith('/')) {
        uriPath = uriPath.substring(0, uriPath.length - 2);
      }
      while (routePath.endsWith('/') && !regex) {
        routePath = routePath.substring(0, routePath.length - 2);
      }
    }
    // test regular expressions
    if (regex) {
      RegExp regexp;
      try {
        regexp = new RegExp(routePath);
        return regexp.hasMatch(uriPath);
      } catch (e) {
        window.console.error(
            "spa-route: error creating regular expression from `${routePath}`. ${e.toString()}");
        return false;
      }
    }
    // usual [path] matching
    return (_uriMatcher(uriPath) != null);
  }

  /// Activates the route with [url] (sets router's active route to [this],
  /// creates route's content).
  void activate(RouteUri url) {
    // allow user to prevent activation of the route (by calling event.preventDefault()).
    bool cont = fireRouteActivate(this,
        path: url.path, newRoute: this, oldRoute: router.activeRoute);
    cont = fireRouteActivate(router,
            path: url.path, newRoute: this, oldRoute: router.activeRoute) &&
        cont;
    cont = fireRouteDeactivate(router.activeRoute,
            path: path, newRoute: this) &&
        cont;
    if (!cont) {
      // don't do anythig if the user executed event.preventDefault()
      return;
    }
    if (redirect != null && redirect != "") {
      router.go(redirect, replace: true);
      return;
    }
    uri = url;

    router.activeRoute = this;
    if (!router.animated && router.previousRoute != null) {
      router.previousRoute.clearContent();
    } else {
      // The router already arranged to clear the previous route and scroll
      // when animation ends. There is no animation if previous route == this.
      if (router.previousRoute == this) {
        router.previousRoute.clearContent();
      }
    }
    if (impl != null && impl != "") {
      // discern the name of the element to create
      if (elem == null || elem == "") {
        elem = impl.split('/').last;
        if (elem.endsWith('.html')) {
          elem = elem.substring(0, elem.length - 5);
        }
        elem = elem.replaceAll(new RegExp(r'[^a-zA-Z]'), '-');
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

  /// Creates custom element [elem]. Definition of [elem] needs to be loaded already.
  void _createCustomElem() {
    if (elem == null || elem == "") {
      window.console
          .error("spa-route: can't guess the name of the element `elem`");
      return;
    }
    Element customElem = document.createElement(elem);
    customElem.attributes.addAll(model);
    if (bindRouter || router.bindRouter) {
      // bind router to customElement.router (if it exists)
      try {
        (customElem as dynamic).router = router;
      } catch (e) {
        window.console.error("""spa-route: error binding router
           (if bindRouter is enabled the route's element must be supported by
           Dart class with public non-final field `router` of type SpaRouter):
           ${e}""");
      }
    }
    append(customElem);
  }

  /// Returns model for the routes's element (for binding to attributes).
  Map<String, String> get model {
    Map<String, String> model = new Map<String, String>();
    if (uri == null) {
      window.console.error("spa-route: can't create model, _uri==null.");
      return model;
    }
    if (uriAttr != null && uriAttr != "") {
      model[uriAttr] = uri.toString();
    }
    // regular expressions can't have path variables
    if (!regex) {
      model.addAll(_uriMatcher(uri.path));
    }
    // extract query parameters
    model.addAll(_queryModel);
    return model;
  }

  /// Generates parts of the [model] from the [uri.search].
  Map<String, String> get _queryModel {
    Map<String, String> qModel = new Map<String, String>();
    List<String> qParams = [];
    List<String> allowedParams;
    if (this.queryParams != null) {
      allowedParams = queryParams.split(' ');
    }
    if (uri.search.length > 1) {
      qParams = uri.search.substring(1).split('&');
      for (String qParam in qParams) {
        List<String> qParamParts = qParam.split('=');
        if (qParamParts.length > 0) {
          if (this.queryParams == '*' ||
              allowedParams.contains(qParamParts[0])) {
            qModel[qParamParts[0]] =
                Uri.decodeQueryComponent(qParamParts.sublist(1).join('='));
          }
        }
      }
    }
    return qModel;
  }

  /// Scrolls to the element with `id="hash"` or `name="hash"`.
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
    new Future(delayedScroll);
  }

  /// Returns a stream of route-activate events. See [fireRouteActivate].
  ElementStream<CustomEvent> get onRouteActivate {
    return this.on[SpaEvent.routeActivate];
  }
  /// Returns a stream of route-deactivate events. See [fireRouteDeactivate].
  ElementStream<CustomEvent> get onRouteDeactivate {
    return this.on[SpaEvent.routeDeactivate];
  }
}

/// Trusting node validator class to validate anything imported by CoreAjax.
class _TrusingNodeValidator implements NodeValidator {
  @override
  bool allowsAttribute(Element element, String attributeName, String value) =>
      true;

  @override
  bool allowsElement(Element element) => true;
}

/// Trusting node validator to validate anything imported by CoreAjax.
final _TrusingNodeValidator _nodeValidator = new _TrusingNodeValidator();
