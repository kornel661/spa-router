web-router
==========

web-router is a HTML5 router element for routing in single page applications.
It's implemented in and compatible with Polymer.dart.

HTML (declarative) syntax makes it easy to use. See [introduction](https://github.com/kornel661/web-router/blob/master/doc/introduction.md)
for some more examples.

The project is still in the EXPERIMENTAL stage and is as for now untested.
Please feel


# Introduction

The easiest way to use web_router dart package is to add it to the `dependencies`
section of your `pubspec.yaml` like
```yaml
dependencies:
  web_router: '^0.0.1'
```
and put necessary imports in your html document:
```html
<link rel="import" href="packages/web_router/web_router.html">
<link rel="import" href="packages/web_router/web_route.html">
```
In your dart files you can add imports
```dart
import 'package:web_router/web_router.dart';
import 'package:web_router/web_route.dart';
```


# Examples


* Basic configuration.
```html
<web-router>
	<web-route path="/">
		<template>
			<p>Inline template! <a href="#/test#fragment">test</a></p>
		</template>
	</web-route>
	<web-route path="/test"><template ref="referencedTemplate"></template></web-route>
	<web-route path="/Test" redirect="/test"></web-route>
	<web-route path="/click/:name" impl="src/click_me.html">
		<web-route path="/" elem="subroute-elem"></web-route>
	</web-route>
	<web-route path="**" elem="other-paths-element"></web-route>
</web-router>

<template id="referencedTemplate">
	<p>TEST <a href="#/">home</a></p>
	<br><br><br><br><br><br><br><br>
	<span id="fragment">Down here.</span>
</template>
```

* Animation (transitions).
```html
<web-router prefix="/anim" animated transitions="hero-transition cross-fade">
	<web-route path="/">
		<template>
			<p>paragraph /</p>
			<span hero hero-id="myHero">HERO!</span>
			<p cross-fade>Inline template!
				<a href="#/anim/test">test</a>
			</p>
		</template>
	</web-route>
	<web-route path="/test">
		<template>
			<p>paragraph /test</p>
			<p cross-fade>TEST <a href="#/anim/">home</a></p>
			<span hero hero-id="myHero">HERO :-)</span>
		</template>
	</web-route>
</web-router>
```

