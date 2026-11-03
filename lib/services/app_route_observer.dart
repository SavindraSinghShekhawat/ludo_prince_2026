import 'package:flutter/material.dart';

/// Central RouteObserver tracking the currently active top-level route.
class AppRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  static final AppRouteObserver instance = AppRouteObserver._internal();
  AppRouteObserver._internal();

  static String? currentRouteName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) {
      currentRouteName = route.settings.name;
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute) {
      currentRouteName = newRoute.settings.name;
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute is PageRoute) {
      currentRouteName = previousRoute.settings.name;
    }
  }
}

