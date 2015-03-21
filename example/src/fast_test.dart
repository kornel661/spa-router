/*
 *  Web Router - dart
 *  Copyright (c) 2015 Kornel Maczyński, pjv, Erik Ringsmuth. For other contributors, see Github.
 */
@HtmlImport('fast_test.html')
library fast_test;

import 'dart:async';
import 'package:polymer/polymer.dart';

import 'package:web_router/web_router.dart';

@CustomTag('fast-test')
class FastTest extends PolymerElement {
  @published String urlA = "/anim/";
  @published String urlB = "/anim/test";
  @published String urlC = "/anim/fast test";

  WebRouter router = null;

  @override
  FastTest.created() : super.created();

  void fastTest() {
    Duration delay = new Duration(milliseconds: 20);
    new Future.delayed(delay, () => router.go(urlA));
    new Future.delayed(delay * 2, () => router.go(urlB));
    new Future.delayed(delay * 3, () => router.go(urlC));
  }
}
