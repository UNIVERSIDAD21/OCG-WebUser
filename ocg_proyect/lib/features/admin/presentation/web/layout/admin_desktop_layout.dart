import 'package:flutter/widgets.dart';

import '../../../../../presentation/web/common/web_breakpoints.dart';

enum AdminDesktopTier { wide, standard, compact, tight }

enum AdminSidebarMode { expanded, collapsed }

class AdminDesktopLayoutData {
  const AdminDesktopLayoutData({
    required this.viewportSize,
    required this.tier,
    required this.sidebarMode,
    required this.sidebarWidth,
    required this.contentMaxWidth,
    required this.pageHorizontalPadding,
    required this.shellGap,
    required this.sectionSpacing,
    required this.panelGap,
    required this.cardMinHeight,
    required this.minSplitPrimaryWidth,
    required this.minSplitSecondaryWidth,
  });

  final Size viewportSize;
  final AdminDesktopTier tier;
  final AdminSidebarMode sidebarMode;
  final double sidebarWidth;
  final double contentMaxWidth;
  final double pageHorizontalPadding;
  final double shellGap;
  final double sectionSpacing;
  final double panelGap;
  final double cardMinHeight;
  final double minSplitPrimaryWidth;
  final double minSplitSecondaryWidth;

  bool get isDesktop => viewportSize.width >= WebBreakpoints.desktopMin;
  bool get isWide => tier == AdminDesktopTier.wide;
  bool get isStandard => tier == AdminDesktopTier.standard;
  bool get isCompact => tier == AdminDesktopTier.compact;
  bool get isTight => tier == AdminDesktopTier.tight;

  double get shellContentViewportWidth =>
      (viewportSize.width - sidebarWidth - shellGap).clamp(0, double.infinity);

  double get constrainedContentWidth =>
      shellContentViewportWidth < contentMaxWidth
      ? shellContentViewportWidth
      : contentMaxWidth;

  double get contentWidth =>
      (constrainedContentWidth - (pageHorizontalPadding * 2)).clamp(
        0,
        double.infinity,
      );

  double resolveSectionGap({double? wide, double? standard, double? compact}) {
    return switch (tier) {
      AdminDesktopTier.wide => wide ?? sectionSpacing,
      AdminDesktopTier.standard => standard ?? sectionSpacing,
      AdminDesktopTier.compact ||
      AdminDesktopTier.tight => compact ?? sectionSpacing,
    };
  }

  bool shouldKeepSplit({
    double? primaryMinWidth,
    double? secondaryMinWidth,
    double? gap,
  }) {
    final primary = primaryMinWidth ?? minSplitPrimaryWidth;
    final secondary = secondaryMinWidth ?? minSplitSecondaryWidth;
    final requiredWidth = primary + secondary + (gap ?? panelGap);
    return contentWidth >= requiredWidth;
  }

  static AdminDesktopLayoutData fromViewport(Size viewportSize) {
    final viewportWidth = viewportSize.width;
    final sidebarMode = viewportWidth < 1360
        ? AdminSidebarMode.collapsed
        : AdminSidebarMode.expanded;
    final sidebarWidth = sidebarMode == AdminSidebarMode.expanded
        ? 248.0
        : 88.0;

    final tier = _resolveTier(
      viewportWidth: viewportWidth,
      sidebarWidth: sidebarWidth,
      shellGap: 0,
    );

    return switch (tier) {
      AdminDesktopTier.wide => AdminDesktopLayoutData(
        viewportSize: viewportSize,
        tier: tier,
        sidebarMode: sidebarMode,
        sidebarWidth: sidebarWidth,
        contentMaxWidth: 1360,
        pageHorizontalPadding: 24,
        shellGap: 0,
        sectionSpacing: 18,
        panelGap: 18,
        cardMinHeight: 118,
        minSplitPrimaryWidth: 420,
        minSplitSecondaryWidth: 360,
      ),
      AdminDesktopTier.standard => AdminDesktopLayoutData(
        viewportSize: viewportSize,
        tier: tier,
        sidebarMode: sidebarMode,
        sidebarWidth: sidebarWidth,
        contentMaxWidth: 1240,
        pageHorizontalPadding: 20,
        shellGap: 0,
        sectionSpacing: 16,
        panelGap: 16,
        cardMinHeight: 112,
        minSplitPrimaryWidth: 400,
        minSplitSecondaryWidth: 340,
      ),
      AdminDesktopTier.compact => AdminDesktopLayoutData(
        viewportSize: viewportSize,
        tier: tier,
        sidebarMode: sidebarMode,
        sidebarWidth: sidebarWidth,
        contentMaxWidth: 1120,
        pageHorizontalPadding: 16,
        shellGap: 0,
        sectionSpacing: 14,
        panelGap: 14,
        cardMinHeight: 106,
        minSplitPrimaryWidth: 380,
        minSplitSecondaryWidth: 320,
      ),
      AdminDesktopTier.tight => AdminDesktopLayoutData(
        viewportSize: viewportSize,
        tier: tier,
        sidebarMode: AdminSidebarMode.collapsed,
        sidebarWidth: 88,
        contentMaxWidth: 1040,
        pageHorizontalPadding: 14,
        shellGap: 0,
        sectionSpacing: 12,
        panelGap: 12,
        cardMinHeight: 100,
        minSplitPrimaryWidth: 340,
        minSplitSecondaryWidth: 300,
      ),
    };
  }

  static AdminDesktopTier _resolveTier({
    required double viewportWidth,
    required double sidebarWidth,
    required double shellGap,
  }) {
    final shellViewportWidth = (viewportWidth - sidebarWidth - shellGap).clamp(
      0,
      double.infinity,
    );

    final tierContentPadding = <AdminDesktopTier, double>{
      AdminDesktopTier.wide: 24,
      AdminDesktopTier.standard: 20,
      AdminDesktopTier.compact: 16,
      AdminDesktopTier.tight: 14,
    };

    final tierMaxWidth = <AdminDesktopTier, double>{
      AdminDesktopTier.wide: 1360,
      AdminDesktopTier.standard: 1240,
      AdminDesktopTier.compact: 1120,
      AdminDesktopTier.tight: 1040,
    };

    double effectiveContentWidth(AdminDesktopTier tier) {
      final constrained = shellViewportWidth < tierMaxWidth[tier]!
          ? shellViewportWidth
          : tierMaxWidth[tier]!;
      return (constrained - (tierContentPadding[tier]! * 2)).clamp(
        0,
        double.infinity,
      );
    }

    final contentWidth = effectiveContentWidth(AdminDesktopTier.wide);
    if (contentWidth >= 1240) return AdminDesktopTier.wide;
    if (effectiveContentWidth(AdminDesktopTier.standard) >= 1100) {
      return AdminDesktopTier.standard;
    }
    if (effectiveContentWidth(AdminDesktopTier.compact) >= 960) {
      return AdminDesktopTier.compact;
    }
    return AdminDesktopTier.tight;
  }
}

class AdminDesktopLayoutScope extends InheritedWidget {
  const AdminDesktopLayoutScope({
    super.key,
    required this.layout,
    required super.child,
  });

  final AdminDesktopLayoutData layout;

  static AdminDesktopLayoutData of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AdminDesktopLayoutScope>();
    if (scope == null) {
      throw FlutterError(
        'AdminDesktopLayoutScope.of() called with no AdminDesktopLayoutScope in context.',
      );
    }
    return scope.layout;
  }

  static AdminDesktopLayoutData? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AdminDesktopLayoutScope>()
        ?.layout;
  }

  @override
  bool updateShouldNotify(AdminDesktopLayoutScope oldWidget) {
    return layout != oldWidget.layout;
  }
}

class AdminDesktopPagePadding extends StatelessWidget {
  const AdminDesktopPagePadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final layout = AdminDesktopLayoutScope.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: layout.pageHorizontalPadding),
      child: child,
    );
  }
}
