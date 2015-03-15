library events;

import 'dart:html';

/// fireEvent(type, detail, node) fires a new CustomEvent(type, detail) on the node
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
  static const activateRouteStart = 'activate-route-start';
  static const routeNotFound = 'route-not-found';
  static const stateChange = 'state-change';
}
