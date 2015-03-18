library events;

import 'dart:html';

/// fireEvent(type, detail, node) fires a new CustomEvent(type, detail) on the node.
/// Returns false if anyone called preventDefault in any of the handlers.
///
/// listen with document.querySelector('node').addEventListener(type, function(event) {
///   event.detail; event.preventDefault();
/// })
bool fireEvent(String type, Object detail, Node node) {
  CustomEvent event =
      new CustomEvent(type, detail: detail, canBubble: false, cancelable: true);
  return node.dispatchEvent(event);
}

class WebEvent {
  // TODO: are dashes allowed in Polymer event names?
  /// fired on the route & router when the route is activated
  static const activateRouteStart = 'activate-route-start';
  static const routeNotFound = 'route-not-found';
  static const stateChange = 'state-change';
}
