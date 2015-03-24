/*
 * SPA router
 * Copyright (c) 2015 Kornel Maczyński.
 * For other contributors, see Github.
 */
library window_location;

import 'package:polymer/polymer.dart';
import 'dart:html';

import 'package:spa_router/spa_router.dart';

@CustomTag('window-location')
class WindowLocation extends PolymerElement {
  @published String arg1 = "";
  @published String arg2 = "";
  @published String arg3 = "";

  @observable SpaRouter router = null;
  @observable DateTime now = new DateTime.now();

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

  void reload() {
  	router.reload();
  }
}
