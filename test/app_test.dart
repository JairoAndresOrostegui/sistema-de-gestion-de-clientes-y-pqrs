import 'package:dts_gestion/core/api.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dts_gestion/core/theme.dart';
import 'package:dts_gestion/features/auth.dart';
import 'package:dts_gestion/features/resources.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));
  test('format uses Bogota even on devices in another timezone', () {
    expect(
      displayDate('2026-09-27T02:00:00Z', time: true),
      contains('26 sept'),
    );
    expect(displayDate('2026-09-27T02:00:00Z', time: true), contains('21:00'));
  });
  test('CSV protects spreadsheet formulas', () {
    expect(csvCell('=HYPERLINK("x")'), startsWith('"\''));
    expect(csvCell('a,b'), '"a,b"');
  });
  for (final code in ['internal', 'unavailable', 'deadline-exceeded']) {
    test(
      'translates transport failure $code without exposing SDK messages',
      () {
        final message = readableError(
          FirebaseFunctionsException(code: code, message: 'internal [0]'),
        );
        expect(message, anyOf(contains('operación'), contains('servicio')));
        expect(message, isNot(contains('[0]')));
      },
    );
  }
  testWidgets('company creation requires only name', (tester) async {
    final session = Session({
      'role': 'owner',
      'uid': 'owner',
      'email': 'owner@example.test',
      'permissions': [],
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: dtsTheme(),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('es', 'CO')],
        home: Scaffold(
          body: ResourceForm(session: session, collection: 'companies'),
        ),
      ),
    );
    expect(find.text('Nombre *'), findsOneWidget);
    final requiredFields = resourceFields['companies']!
        .where((f) => f.required)
        .toList();
    expect(requiredFields.map((f) => f.key), ['name']);
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(390, 844), const Size(1440, 1000)]) {
    testWidgets('login renders without overflow at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(theme: dtsTheme(), home: const LoginPage()),
      );
      expect(find.text('Continuar con Google'), findsOneWidget);
      expect(find.text('Bienvenido a DTS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
