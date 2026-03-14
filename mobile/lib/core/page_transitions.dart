import 'package:flutter/material.dart';
import 'app_animations.dart';

/// Custom page route transitions for navigation.
class AppPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final PageTransitionType type;

  AppPageRoute({
    required this.page,
    this.type = PageTransitionType.fadeSlideUp,
  }) : super(
          transitionDuration: AppAnimations.pageTransition,
          reverseTransitionDuration: AppAnimations.normal,
          pageBuilder: (context, animation, secondaryAnim) => page,
          transitionsBuilder: (context, animation, secondaryAnim, child) {
            switch (type) {
              case PageTransitionType.fadeSlideUp:
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: AppAnimations.enterCurve,
                  )),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: AppAnimations.enterCurve,
                    ),
                    child: child,
                  ),
                );

              case PageTransitionType.slideRight:
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: AppAnimations.enterCurve,
                  )),
                  child: child,
                );

              case PageTransitionType.fadeScale:
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: AppAnimations.enterCurve,
                      ),
                    ),
                    child: child,
                  ),
                );
            }
          },
        );
}

enum PageTransitionType {
  fadeSlideUp,
  slideRight,
  fadeScale,
}
