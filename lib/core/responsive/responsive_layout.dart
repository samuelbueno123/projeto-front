import 'package:flutter/material.dart';

/// Screen size category for responsive layouts.
enum ScreenType {
  mobile,
  tablet,
  desktop,
  ultrawide,
}

/// Utility for responsive breakpoints and layout adaptations.
class ResponsiveLayout {
  static const double mobileMaxWidth = 640;
  static const double tabletMaxWidth = 1024;
  static const double desktopMaxWidth = 1600;

  static ScreenType screenType(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < mobileMaxWidth) return ScreenType.mobile;
    if (width < tabletMaxWidth) return ScreenType.tablet;
    if (width < desktopMaxWidth) return ScreenType.desktop;
    return ScreenType.ultrawide;
  }

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileMaxWidth;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileMaxWidth && width < tabletMaxWidth;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletMaxWidth;

  static bool isWideOrDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mobileMaxWidth;

  /// Returns responsive value based on current screen size.
  static T value<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    required T desktop,
    T? ultrawide,
  }) {
    final type = screenType(context);
    switch (type) {
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet ?? desktop;
      case ScreenType.desktop:
        return desktop;
      case ScreenType.ultrawide:
        return ultrawide ?? desktop;
    }
  }
}

/// A widget builder that adapts to Mobile, Tablet, and Desktop screens.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  final Widget Function(BuildContext context) mobile;
  final Widget Function(BuildContext context)? tablet;
  final Widget Function(BuildContext context) desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveLayout.tabletMaxWidth) {
          return desktop(context);
        }
        if (constraints.maxWidth >= ResponsiveLayout.mobileMaxWidth) {
          return (tablet ?? desktop)(context);
        }
        return mobile(context);
      },
    );
  }
}
