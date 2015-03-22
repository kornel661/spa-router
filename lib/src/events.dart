library events;

import 'dart:html';

import 'package:web_router/web_router.dart';
import 'package:web_router/web_route.dart';

/// Fires a new [CustomEvent]([type], [detail]) on the [node].
/// Returns false if anyone called preventDefault in any of the handlers.
///
/// listen with document.querySelector('node').addEventListener(type, function(event) {
///   event.detail; event.preventDefault();
/// })
bool _fireEvent(Node node, String type, [Object detail]) {
  CustomEvent event =
      new CustomEvent(type, detail: detail, canBubble: false, cancelable: true);
  return node.dispatchEvent(event);
}

/// Class holding names of the events used by [WebRouter] and [WebRoute].
class WebEvent {
  static const addressChange = "address-change";
  static const routeNotFound = 'route-not-found';
  static const routeActivate = 'route-activate';
}

/// Fires [WebEvent.addressChange] event on [node] ([WebRouter]) signaling that
/// new path is [newPath].
///
/// event.preventDefault() prevents the router from acting on this change (the
/// change is ignored).
bool fireAddressChange(WebRouter node, String newPath) {
  return _fireEvent(node, WebEvent.addressChange, {'path': newPath});
}

/// Fires [WebEvent.routeNotFound] event on [node] ([WebRouter]) signaling that
/// router couldn't find a route matching to [path].
bool fireRouteNotFound(WebRouter node, String path) {
  return _fireEvent(node, WebEvent.routeNotFound, {'path': path});
}

/// Fires [WebEvent.routeActivate] event on [node] ([WebRouter], [WebRoute])
/// signaling that new path is [path] and the previous route [oldRoute] is about
/// to give place to [newRoute].
///
/// The event is fired on the [newRoute] and the [WebRouter]. At the time the
/// event is fired the [oldRoute] is currently active and [newRoute] is about
/// to become active.
///
/// event.preventDefault() prevents the change from happening.
bool fireRouteActivate(Node node,
    {String path, WebRoute newRoute, WebRoute oldRoute}) {
  return _fireEvent(node, WebEvent.routeNotFound, {
    'path': path,
    'newRoute': newRoute,
    'oldRoute': oldRoute
  });
}
