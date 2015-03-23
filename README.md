spa-router
==========

spa-router is a HTML5 router element for well-suited for single page applications.
It's implemented in and compatible with Polymer.dart. It's distributed under MIT
[license](https://github.com/kornel661/spa-router/blob/master/LICENSE).

HTML (declarative) syntax makes it easy to use. See [introduction](https://github.com/kornel661/spa-router/blob/master/doc/introduction.md)
for some more examples. Live demos are coming...

The project is still in the EXPERIMENTAL stage and is as for now untested.
Please feel free to try it out, test and contribute. Source code is available on
[github](https://github.com/kornel661/spa-router). You can also
[report problems and issues](https://github.com/kornel661/spa-router/issues) there.


# Introduction

The easiest way to use spa_router dart package is to add it to the `dependencies`
section of your `pubspec.yaml` like
```yaml
dependencies:
  spa_router: '^0.1.0+2'
```
and put necessary imports in your html document:
```html
<link rel="import" href="packages/spa_router/spa_router.html">
<link rel="import" href="packages/spa_router/spa_route.html">
```
In your dart files you can add imports
```dart
import 'package:spa_router/spa_router.dart';
import 'package:spa_router/spa_route.dart';
```


# Examples


* Basic configuration.
```html
<spa-router>
	<spa-route path="/">
		<template>
			<p>Inline template! <a href="#/test@@fragment">test</a></p>
		</template>
	</spa-route>
	<spa-route path="/test"><template ref="referencedTemplate"></template></spa-route>
	<spa-route path="/Test" redirect="/test"></spa-route>
	<spa-route path="/click/:name" impl="src/click_me.html">
		<spa-route path="/" elem="subroute-elem"></spa-route>
	</spa-route>
	<spa-route path="**" elem="other-paths-element"></spa-route>
</spa-router>

<template id="referencedTemplate">
	<p>TEST <a href="#/">home</a></p>
	<br><br><br><br><br><br><br><br>
	<span id="fragment">Down here.</span>
</template>
```

* Animation (transitions).
```html
<spa-router prefix="/anim" animated transitions="hero-transition cross-fade">
	<spa-route path="/">
		<template>
			<p>paragraph /</p>
			<span hero hero-id="myHero">HERO!</span>
			<p cross-fade>Inline template!
				<a href="#/anim/test">test</a>
			</p>
		</template>
	</spa-route>
	<spa-route path="/test">
		<template>
			<p>paragraph /test</p>
			<p cross-fade>TEST <a href="#/anim/">home</a></p>
			<span hero hero-id="myHero">HERO :-)</span>
		</template>
	</spa-route>
</spa-router>
```

