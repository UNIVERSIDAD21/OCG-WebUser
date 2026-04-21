import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/admin/presentation/web/components/split_view_layout.dart';
import 'package:ocg_proyect/features/admin/presentation/web/layout/admin_desktop_layout.dart';

void main() {
  group('AdminDesktopLayoutData', () {
    test('resuelve tiers por ancho útil real del contenido', () {
      expect(
        AdminDesktopLayoutData.fromViewport(const Size(1600, 900)).tier,
        AdminDesktopTier.wide,
      );
      expect(
        AdminDesktopLayoutData.fromViewport(const Size(1366, 768)).tier,
        AdminDesktopTier.standard,
      );
      expect(
        AdminDesktopLayoutData.fromViewport(const Size(1220, 900)).tier,
        AdminDesktopTier.compact,
      );
      expect(
        AdminDesktopLayoutData.fromViewport(const Size(980, 820)).tier,
        AdminDesktopTier.tight,
      );
    });

    test('colapsa sidebar antes de degradar paneles en desktop pequeño', () {
      final wide = AdminDesktopLayoutData.fromViewport(const Size(1600, 900));
      final standard = AdminDesktopLayoutData.fromViewport(
        const Size(1366, 768),
      );
      final compact = AdminDesktopLayoutData.fromViewport(
        const Size(1280, 800),
      );
      final tight = AdminDesktopLayoutData.fromViewport(const Size(980, 820));

      expect(wide.sidebarMode, AdminSidebarMode.expanded);
      expect(standard.sidebarMode, AdminSidebarMode.rail);
      expect(compact.sidebarMode, AdminSidebarMode.rail);
      expect(tight.sidebarMode, AdminSidebarMode.compactRail);
      expect(compact.contentWidth, greaterThan(1000));
    });
  });

  testWidgets(
    'SplitViewLayout baja el panel secundario cuando el tier ya no soporta split',
    (WidgetTester tester) async {
      const layout = AdminDesktopLayoutData(
        viewportSize: Size(980, 820),
        tier: AdminDesktopTier.tight,
        sidebarMode: AdminSidebarMode.compactRail,
        sidebarWidth: 76,
        contentMaxWidth: 1200,
        pageHorizontalPadding: 12,
        shellGap: 0,
        sectionSpacing: 12,
        panelGap: 12,
        cardMinHeight: 100,
        minSplitPrimaryWidth: 340,
        minSplitSecondaryWidth: 300,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminDesktopLayoutScope(
              layout: layout,
              child: SplitViewLayout(
                primaryMinWidth: 620,
                secondaryMinWidth: 420,
                left: SizedBox(height: 40, child: Text('izquierda')),
                right: SizedBox(height: 40, child: Text('derecha')),
              ),
            ),
          ),
        ),
      );

      final leftTopLeft = tester.getTopLeft(find.text('izquierda'));
      final rightTopLeft = tester.getTopLeft(find.text('derecha'));
      expect(rightTopLeft.dy, greaterThan(leftTopLeft.dy));
    },
  );
}
