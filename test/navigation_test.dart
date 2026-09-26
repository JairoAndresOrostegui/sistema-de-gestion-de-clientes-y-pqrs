import 'dart:async';
import 'package:dts_gestion/core/api.dart';
import 'package:dts_gestion/features/admin.dart';
import 'package:dts_gestion/features/auth.dart';
import 'package:dts_gestion/features/resources.dart';
import 'package:dts_gestion/features/shell.dart';
import 'package:dts_gestion/features/tickets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'ui_audit_test.dart' as audit;

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);
  setUp(() => Api.testTransport = audit.fixture);
  tearDown(() => Api.testTransport = null);
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(844, 390),
    const Size(1440, 900),
  ]) {
    testWidgets('owner navigates every destination $size', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await audit.mount(
        tester,
        AppShell(session: audit.session()),
        size,
        scroll: false,
      );
      final labels = [
        'Resumen',
        'Solicitudes y PQRS',
        'Empresas',
        'Proyectos',
        'Instalaciones y versiones',
        'Productos y soluciones',
        'Personas y estructura',
        'Catálogo funcional',
        'Contratos y cobertura',
        'Servicios y renovaciones',
        'Implementación y agenda',
        'Base de conocimientos',
        'Valores y movimientos',
        'Enlazar proyecto',
        'Usuarios y permisos',
        'Notificaciones',
        'Mi cuenta',
      ];
      for (final label in labels) {
        if (size.width < 1080) {
          await tester.tap(find.byTooltip('Abrir menú'));
          await tester.pumpAndSettle();
        }
        final tile = find.widgetWithText(ListTile, label);
        await tester.scrollUntilVisible(
          tile,
          80,
          scrollable: find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(find.text('DTS / $label'), findsOneWidget, reason: label);
        expect(tester.takeException(), isNull, reason: label);
      }
    });
    testWidgets('dialogs open and close $size', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await audit.mount(tester, AccessPage(session: audit.session()), size);
      await tester.ensureVisible(find.byTooltip('Editar permisos'));
      await tester.tap(find.byTooltip('Editar permisos'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await audit.mount(
        tester,
        TicketDetail(session: audit.session(), id: 'ticket1'),
        size,
        scroll: false,
      );
      await tester.ensureVisible(find.text('Actualizar estado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actualizar estado'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await audit.mount(
        tester,
        ResourcePage(
          session: audit.session(),
          collection: 'companies',
          onScope: () {},
        ),
        size,
      );
      final row = find.widgetWithText(ListTile, audit.longName).first;
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  }
  for (final role in ['commercial', 'technician', 'client', 'reader']) {
    testWidgets('navigation respects $role role', (tester) async {
      await audit.mount(
        tester,
        AppShell(session: audit.session(role)),
        const Size(1440, 900),
        scroll: false,
      );
      expect(
        find.widgetWithText(ListTile, 'Usuarios y permisos'),
        findsNothing,
      );
      expect(
        find.widgetWithText(ListTile, 'Enlazar proyecto'),
        role == 'technician' ? findsOneWidget : findsNothing,
      );
      if (role == 'commercial') {
        await tester.scrollUntilVisible(
          find.widgetWithText(ListTile, 'Valores y movimientos'),
          80,
          scrollable: find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
      }
      expect(
        find.widgetWithText(ListTile, 'Valores y movimientos'),
        role == 'commercial' ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('empty login validates without submitting', (tester) async {
    await audit.mount(
      tester,
      const LoginPage(),
      const Size(390, 844),
      scroll: false,
    );
    await tester.ensureVisible(find.text('Iniciar sesión'));
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe un correo válido'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('save locks during request and preserves form on failure', (
    tester,
  ) async {
    var saves = 0;
    final response = Completer<Json>();
    Api.testTransport = (action, data) {
      if (action == 'save') {
        saves++;
        return response.future;
      }
      return audit.fixture(action, data);
    };
    await audit.mount(
      tester,
      ResourceForm(session: audit.session(), collection: 'companies'),
      const Size(390, 844),
      scroll: false,
    );
    await tester.enterText(find.byType(TextFormField).first, 'Empresa válida');
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(find.text('Guardando…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardando…'))
          .onPressed,
      isNull,
    );
    response.completeError(Exception('Simulated timeout'));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(find.text('Empresa válida'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    for (final collection in [...resourceFields.keys, 'ticket']) {
      testWidgets('keyboard keeps $collection usable at $size', (tester) async {
        addTearDown(tester.view.resetViewInsets);
        tester.view.viewInsets = FakeViewPadding(
          bottom: size.height > 500 ? 300 : 150,
        );
        await audit.mount(
          tester,
          collection == 'ticket'
              ? TicketForm(session: audit.session())
              : ResourceForm(session: audit.session(), collection: collection),
          size,
          scroll: false,
        );
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  test('calendar validation rejects rollover dates and accepts leap day', () {
    expect(parseCalendarDate('2026-02-30'), isNull);
    expect(parseCalendarDate('2026-02-29'), isNull);
    expect(parseCalendarDate('2024-02-29'), isNotNull);
    expect(parseCalendarDate('2026-13-01'), isNull);
  });
  testWidgets('date picker recovers from a typed date outside its range', (
    tester,
  ) async {
    await audit.mount(
      tester,
      ResourceForm(session: audit.session(), collection: 'services'),
      const Size(390, 844),
      scroll: false,
    );
    final dateField = find.widgetWithText(TextFormField, 'Fecha de inicio *');
    await tester.ensureVisible(dateField);
    await tester.enterText(dateField, '1900-01-01');
    await tester.pumpAndSettle();
    final icon = find.descendant(
      of: dateField,
      matching: find.byType(IconButton),
    );
    await tester.ensureVisible(icon);
    await tester.pumpAndSettle();
    await tester.tap(icon);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
