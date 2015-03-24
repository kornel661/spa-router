/*
 * SPA router
 * Copyright (c) 2015 Kornel Maczyński.
 * For other contributors, see Github.
 */
library events;

import 'dart:html';

import 'package:spa_router/spa_router.dart';
import 'package:spa_router/spa_route.dart';

/// Fires a new [CustomEvent]([type], [detail]) on the [node].
/// Returns false if anyone called preventDefault in any of the handlers.
///
/// listen with document.querySelector('node').addEventListener(type, function(event) {
///   event.detail; event.preventDefault();
/// })
bool _fireEvent(Node node, String type, [Map<String, Object> detail]) {
  CustomEvent event =
      new CustomEvent(type, detail: detail, canBubble: false, cancelable: true);
  return node.dispatchEvent(event);
}

/// Class holding names of the events used by [SpaRouter] and [SpaRoute].
class SpaEvent {
  static const addressChange = "address-change";
  static const routeNotFound = 'route-not-found';
  static const routeActivate = 'route-activate';
  static const routeDeactivate = 'route-deactivate';
}

/// Fires [SpaEvent.addressChange] event on [node] ([SpaRouter]) signaling that
/// new path is [newPath].
///
/// event.preventDefault() prevents the router from acting on this change (the
/// change is ignored).
bool fireAddressChange(SpaRouter node, String newPath) {
  return _fireEvent(node, SpaEvent.addressChange, {'path': newPath});
}

/// Fires [SpaEvent.routeNotFound] event on [node] ([SpaRouter]) signaling that
/// router couldn't find a route matching to [path].
bool fireRouteNotFound(SpaRouter node, String path) {
  return _fireEvent(node, SpaEvent.routeNotFound, {'path': path});
}

/// Fires [SpaEvent.routeActivate] event on [node] ([SpaRouter], [SpaRoute])
/// signaling that new path is [path] and the previous route [oldRoute] is about
/// to give place to [newRoute].
///
/// The event is fired on the [newRoute] and the [SpaRouter]. At the time the
/// event is fired the [oldRoute] is currently active and [newRoute] is about
/// to become active.
///
/// event.preventDefault() prevents the change from happening.
bool fireRouteActivate(Node node,
    {String path, SpaRoute newRoute, SpaRoute oldRoute}) {
  return _fireEvent(node, SpaEvent.routeActivate, {
    'path': path,
    'newRoute': newRoute,
    'oldRoute': oldRoute
  });
}

/// Fires [SpaEvent.routeDeactivate] event on [node] - a route that is about to
/// be deactivated.
bool fireRouteDeactivate(SpaRoute node,
    {String path, SpaRoute newRoute}) {
	if (node == null) {
		return true;
	}
  return _fireEvent(node, SpaEvent.routeDeactivate, {
    'path': path,
    'newRoute': newRoute,
    'oldRoute': node
  });
}
