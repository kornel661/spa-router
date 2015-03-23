/*
 * SPA router
 * Copyright (c) 2015 Kornel Maczyński.
 * For other contributors, see Github.
 */
library fast_test;

import 'dart:async';
import 'package:polymer/polymer.dart';

import 'package:spa_router/spa_router.dart';

@CustomTag('fast-test')
class FastTest extends PolymerElement {
  @published String urlA = "/anim/";
  @published String urlB = "/anim/test";
  @published String urlC = "/anim/fast test";

  SpaRouter router = null;

  @override
  FastTest.created() : super.created();

  void fastTest() {
    Duration delay = new Duration(milliseconds: 20);
    new Future.delayed(delay, () => router.go(urlA));
    new Future.delayed(delay * 2, () => router.go(urlB));
    new Future.delayed(delay * 3, () => router.go(urlC));
  }
}
