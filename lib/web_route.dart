/*
 *  Web Router - dart
 *  Copyright (c) 2015 Kornel Maczyński, pjv, Erik Ringsmuth. For other contributors, see Github.
 */

import 'package:polymer/polymer.dart';
import 'dart:html';

/// web-route is an element describing a route within a web-router element.
/// Some syntax:
/// <app-route path="/path" [imp="/page/cust-elem.html"] [elem="cust-el"] [template] [regex] [bindRouter]></app-route>
@CustomTag('web-route')
class WebRoute extends PolymerElement with Observable {
	/// Path of the route.
	@published String path = "/";
	/// Path to the implementation of the element to be shown.
	@published String imp;
	/// Name of the element to be shown.
	@published String elem;
	/// If not empty the route redirects there.
	@published String redirect;
	/// Is it an inline template?
	@published bool template = false;
	/// Is the path is a regular expression?
	@published bool regex = false;
	/// Is transition animation in progress?
	bool transitionAnimationInProgress = false;
	/// Is the route is active?
	@published bool active = false;
	/// Whether to bind the router to the element.
	@published bool bindRouter;
	
	Element _contentContainer;
	
	@override
	WebRoute.created() : super.created();
	
	@override
	void ready() {
		_contentContainer = shadowRoot.querySelector("content");
		//print("ready: path ${path}!\n");
	}
	
	void setContent(content, validator) {
		_contentContainer.setInnerHtml(content, validator: validator);
	}
	
	Element getContent() {
		return _contentContainer;
	}
	
	@override
	String toString() => "path: $path, imp: $imp, elem: $elem, template: $template, regex: $regex, redirect: $redirect, transitionAnimationInProgress: $transitionAnimationInProgress, active: $active, bindRouter: $bindRouter";
}
