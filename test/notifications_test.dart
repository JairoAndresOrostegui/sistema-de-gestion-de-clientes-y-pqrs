import 'package:dts_gestion/core/api.dart';
import 'package:dts_gestion/core/widgets.dart';
import 'package:dts_gestion/features/admin.dart';
import 'package:dts_gestion/features/notification_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'ui_audit_test.dart' as audit;

final deliveries = [
  {
    'slot': 'web',
    'status': 'accepted',
    'receivedAt': '2026-09-26T16:00:00Z',
    'readAt': '2026-09-26T16:02:00Z',
    'attempts': 1,
  },
  {'slot': 'mobile', 'status': 'retry', 'attempts': 3},
];
Future<Json> transport(String action, Json data) async {
  if (action == 'myDevices') {
    return {
      'items': [
        for (final slot in ['web', 'mobile'])
          {
            'slot': slot,
            'label': audit.longName,
            'lastLoginAt': '2026-09-26T15:00:00Z',
            'enabled': true,
            'current': slot == 'web',
          },
      ],
    };
  }
  if (action == 'ticketNotifications') {
    return {
      'items': [
        {
          'id': 'event',
          'body': audit.longName,
          'createdAt': '2026-09-26T15:00:00Z',
          'device': {'label': audit.longName},
          'recipients': [
            {
              'recipient':
                  'nombre.extremadamente.largo.para.probar@example.test',
              'readAt': null,
              'deliveries': deliveries,
            },
          ],
        },
      ],
    };
  }
  if (action == 'list' && data['collection'] == 'notifications') {
    return {
      'items': [
        {
          'id': 'notice',
          'body': audit.longName,
          'createdAt': '2026-09-26T15:00:00Z',
          'deliveries': deliveries,
        },
      ],
    };
  }
  return audit.fixture(action, data);
}

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));
  setUp(() {
    Api.testTransport = transport;
  });
  tearDown(() {
    Api.testTransport = null;
  });
  for (final (size, scale) in [
    (const Size(320, 568), 1.0),
    (const Size(390, 844), 1.0),
    (const Size(768, 1024), 1.0),
    (const Size(1440, 900), 1.0),
    (const Size(844, 390), 1.0),
    (const Size(390, 844), 2.0),
  ]) {
    testWidgets('last devices with long labels ${size.width} text $scale', (
      tester,
    ) async {
      await audit.mount(tester, const DevicesCard(), size, scale: scale);
      expect(find.textContaining('Último acceso:'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
    testWidgets('expanded delivery inbox ${size.width} text $scale', (
      tester,
    ) async {
      await audit.mount(
        tester,
        NotificationsPage(session: audit.session()),
        size,
        scale: scale,
      );
      await tester.ensureVisible(find.byType(ExpansionTile));
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.textContaining('Aceptado por Firebase'), findsOneWidget);
      expect(find.textContaining('Reintento pendiente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'expanded ticket notification trace ${size.width} text $scale',
      (tester) async {
        await audit.mount(
          tester,
          const TicketNotificationTrace(ticketId: 'ticket1'),
          size,
          scale: scale,
          scroll: false,
        );
        await tester.ensureVisible(find.byType(ExpansionTile));
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();
        expect(find.textContaining('Lectura sin confirmar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('device request fails visibly and recovers on retry', (
    tester,
  ) async {
    bool failed = true;
    Api.testTransport = (action, data) =>
        failed ? Future.error(Exception('offline')) : transport(action, data);
    await audit.mount(tester, const DevicesCard(), const Size(390, 844));
    expect(find.byType(ErrorPanel), findsOneWidget);
    failed = false;
    await tester.tap(find.text('Volver a intentar'));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorPanel), findsNothing);
    expect(find.textContaining('Último acceso:'), findsNWidgets(2));
  });
}
