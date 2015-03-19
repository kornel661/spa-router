/*
 *  Web Router - dart
 *  Copyright (c) 2015 Kornel Maczyński, pjv, Erik Ringsmuth. For other contributors, see Github.
 */

import 'package:polymer/polymer.dart';
import 'dart:html';

@CustomTag('window-location')
class WindowLocation extends PolymerElement {
  @override
  WindowLocation.created() : super.created();

  @override
  void ready() {
    super.ready();
    shadowRoot.querySelector("content").innerHtml = window.location.href;
  }
}
