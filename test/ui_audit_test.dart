import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dts_gestion/core/api.dart';
import 'package:dts_gestion/core/theme.dart';
import 'package:dts_gestion/core/widgets.dart';
import 'package:dts_gestion/features/admin.dart';
import 'package:dts_gestion/features/auth.dart';
import 'package:dts_gestion/features/imports.dart';
import 'package:dts_gestion/features/resources.dart';
import 'package:dts_gestion/features/shell.dart';
import 'package:dts_gestion/features/tickets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const longName =
    'Empresa de Desarrollo y Tecnología con un nombre deliberadamente largo para verificar el espacio disponible';
final ticket = <String, dynamic>{
  'id': 'ticket1',
  'companyId': 'company1',
  'projectId': 'project1',
  'number': 'DTS-000001',
  'subject': longName,
  'description': longName,
  'status': 'esperando_cliente',
  'priority': 'critica',
  'category': 'incidente',
  'coverage': 'fuera_cobertura',
  'requesterId': 'owner',
  'createdAt': '2026-09-26T15:00:00Z',
  'updatedAt': '2026-09-26T15:00:00Z',
  'timeMinutes': 120,
};

Session session([String role = 'owner']) =>
    Session({
        'role': role,
        'uid': 'owner',
        'email': 'nombre.extenso.para.prueba@example.test',
        'permissions': [],
      })
      ..companyId = 'company1'
      ..projectId = 'project1'
      ..companies = [
        {'id': 'company1', 'name': longName},
      ]
      ..projects = [
        {'id': 'project1', 'companyId': 'company1', 'name': longName},
      ];

Future<Json> fixture(String action, Json data) async {
  if (action == 'dashboard') {
    return {'open': 12345, 'new': 99, 'activeProjects': 20, 'resolved': 123456};
  }
  if (action == 'ticketDetail') {
    return {
      'ticket': ticket,
      'items': [
        {
          'id': 'message',
          'kind': 'comment',
          'body': longName,
          'authorId': 'owner',
          'createdAt': '2026-09-26T15:00:00Z',
          'audience': 'public',
          'attachments': [],
        },
      ],
      'cursor': null,
    };
  }
  final c = data['collection'];
  return {
    'items': c == 'tickets'
        ? [ticket]
        : c == 'users'
        ? [
            {
              'id': 'owner',
              'email': 'nombre.largo@example.test',
              'role': 'owner',
              'active': true,
            },
          ]
        : c == 'notifications'
        ? [
            {
              'id': 'notice',
              'body': longName,
              'createdAt': '2026-09-26T15:00:00Z',
            },
          ]
        : [
            {
              'id': 'record',
              'companyId': 'company1',
              'projectId': 'project1',
              'name': longName,
              'description': longName,
              'status': c == 'events' ? 'pendiente' : 'activo',
              'type': c == 'events' ? 'capacitacion' : 'soporte',
              'endDate': '2027-01-01',
              'dueDate': '2026-10-01',
              'published': true,
              'amount': 123456789,
              'currency': 'COP',
              'version': '1.2.3',
            },
          ],
    'cursor': null,
  };
}

Future<void> mount(
  WidgetTester tester,
  Widget child,
  Size size, {
  double scale = 1,
  bool scroll = true,
}) async {
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: dtsTheme(),
      locale: const Locale('es', 'CO'),
      supportedLocales: const [Locale('es', 'CO')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: scroll
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: child,
              )
            : child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));
  setUp(() {
    Api.testTransport = fixture;
  });
  tearDown(() => Api.testTransport = null);
  const viewports = [
    (Size(320, 568), 1.0),
    (Size(390, 844), 1.0),
    (Size(768, 1024), 1.0),
    (Size(1024, 768), 1.0),
    (Size(1440, 900), 1.0),
    (Size(844, 390), 1.0),
    (Size(390, 844), 2.0),
  ];
  for (final (size, scale) in viewports) {
    final tag = '${size.width.toInt()}x${size.height.toInt()} text=$scale';
    final pages = <String, Widget Function(Session)>{
      'dashboard': (s) => DashboardPage(session: s, navigate: (_) {}),
      'tickets': (s) => TicketsPage(session: s),
      'detail': (s) => TicketDetail(session: s, id: 'ticket1'),
      'imports': (s) => ImportsPage(session: s),
      'access': (s) => AccessPage(session: s),
      'notifications': (s) => NotificationsPage(session: s),
      'account': (s) => AccountPage(session: s),
      for (final c in resourceTitles.keys)
        c: (s) => ResourcePage(session: s, collection: c, onScope: () {}),
    };
    for (final page in pages.entries) {
      testWidgets('${page.key} populated $tag', (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await mount(
          tester,
          page.value(session()),
          size,
          scale: scale,
          scroll: page.key != 'detail',
        );
        expect(tester.takeException(), isNull);
        final scrolls = find.byType(Scrollable);
        if (scrolls.evaluate().isNotEmpty) {
          await tester.drag(scrolls.first, const Offset(0, -1200));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      });
    }
    for (final collection in [...resourceFields.keys, 'ticket']) {
      testWidgets('form $collection $tag', (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await mount(
          tester,
          collection == 'ticket'
              ? TicketForm(session: session())
              : ResourceForm(session: session(), collection: collection),
          size,
          scale: scale,
          scroll: false,
        );
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -4000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('login $tag', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, const LoginPage(), size, scale: scale, scroll: false);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('request fails, shows recovery and succeeds on retry', (
    tester,
  ) async {
    var fail = true;
    Api.testTransport = (action, data) async {
      if (fail) {
        throw FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Sin conexión temporal',
        );
      }
      return fixture(action, data);
    };
    await mount(
      tester,
      ResourcePage(session: session(), collection: 'companies', onScope: () {}),
      const Size(390, 844),
    );
    expect(
      find.text(
        'No se pudo conectar con el servicio. Revisa tu conexión e intenta nuevamente.',
      ),
      findsOneWidget,
    );
    fail = false;
    await tester.tap(find.text('Volver a intentar'));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorPanel), findsNothing);
    expect(find.text(longName), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  test('rapid company changes ignore an obsolete response', () async {
    final first = Completer<Json>(), second = Completer<Json>();
    Api.testTransport = (action, data) =>
        data['companyId'] == 'A' ? first.future : second.future;
    final s = session();
    final a = s.selectCompany('A'), b = s.selectCompany('B');
    second.complete({
      'items': [
        {'id': 'B-project', 'name': 'B', 'companyId': 'B'},
      ],
    });
    await b;
    first.complete({
      'items': [
        {'id': 'A-project', 'name': 'A', 'companyId': 'A'},
      ],
    });
    await a;
    expect(s.companyId, 'B');
    expect(s.projects.single['id'], 'B-project');
  });
  test(
    'obsolete company request failure does not replace the current context',
    () async {
      final old = Completer<Json>();
      Api.testTransport = (action, data) => data['companyId'] == 'A'
          ? old.future
          : Future.value({
              'items': [
                {'id': 'B-project', 'companyId': 'B', 'name': 'B'},
              ],
            });
      final s = session();
      final pending = s.selectCompany('A');
      await s.selectCompany('B');
      old.completeError(Exception('Old network request failed'));
      await pending;
      expect(s.companyId, 'B');
      expect(s.projects.single['id'], 'B-project');
    },
  );
}
