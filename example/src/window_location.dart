/*
 *  Web Router - dart
 *  Copyright (c) 2015 Kornel Maczyński, pjv, Erik Ringsmuth. For other contributors, see Github.
 */

import 'package:polymer/polymer.dart';
import 'dart:html';

import 'package:web_router/web_router.dart';

@CustomTag('window-location')
class WindowLocation extends PolymerElement {
  @published String arg1 = "";
  @published String arg2 = "";
  @published String arg3 = "";

  @observable WebRouter router = null;

  @override
  WindowLocation.created() : super.created();

  @override
  void ready() {
    super.ready();
    shadowRoot.querySelector("content").innerHtml = window.location.href;
  }

  void go() {
  	router.go("/");
  }
}
