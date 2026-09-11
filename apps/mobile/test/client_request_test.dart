import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:weyonje/app.dart';
import 'package:weyonje/core/auth/auth_providers.dart';
import 'package:weyonje/core/auth/auth_repository.dart';
import 'package:weyonje/core/auth/current_actor.dart';
import 'package:weyonje/features/workflows/application/client_location_gateway.dart';
import 'package:weyonje/features/workflows/application/workflow_providers.dart';
import 'package:weyonje/features/workflows/data/workflow_repository.dart';
import 'package:weyonje/features/workflows/domain/workflow_models.dart';
import 'package:weyonje/features/workflows/presentation/request_service_screen.dart';
import 'package:weyonje/features/workflows/presentation/weyonje_map.dart';
import 'package:weyonje/ui/weyonje_button.dart';
import 'package:weyonje/ui/weyonje_select.dart';

import 'support/fake_auth_repository.dart';

const actor = CurrentActor(
  actorType: ActorType.client,
  access: ActorAccess.eligible,
);

class RequestWorkflows extends Fake implements WorkflowRepository {
  Map<String, dynamic> profile = {
    'clientName': 'Amina Test',
    'phoneNumber': '+256700000123',
  };
  bool profileFails = false;
  String? failureCode = 'INVALID_REQUEST';
  final submissions = <Map<String, Object?>>[];
  final addresses = <Completer<String?>>[];
  bool holdAddresses = false;
  @override
  Future<Map<String, dynamic>> clientProfile() async {
    if (profileFails) throw Exception('offline');
    return profile;
  }

  @override
  Future<WorkflowDashboard> clientDashboard() async => const WorkflowDashboard(
    pendingCount: 0,
    activeCount: 0,
    actionRequiredCount: 0,
    recentRequests: [],
  );
  @override
  Future<String?> reverseGeocode(double latitude, double longitude) {
    if (!holdAddresses) return Future.value('Resolved test address');
    final pending = Completer<String?>();
    addresses.add(pending);
    return pending.future;
  }

  @override
  Future<ServiceRequestDetail> createClientRequest(
    Map<String, Object?> data,
  ) async {
    submissions.add(data);
    throw WorkflowException(
      'The response was interrupted. Retry.',
      code: failureCode,
    );
  }
}

class RequestLocations extends Fake implements ClientLocationGateway {
  ClientLocationAccess access = ClientLocationAccess.ready;
  int checks = 0;
  int captures = 0;
  int settingsCalls = 0;
  Completer<DevicePoint>? pending;
  @override
  Future<ClientLocationAccess> check({bool requestPermission = false}) async {
    checks++;
    return access;
  }

  @override
  Future<DevicePoint> current() async {
    captures++;
    return pending == null
        ? DevicePoint(
            sampleId: 'test',
            latitude: 0.3,
            longitude: 32.5,
            accuracyMetres: 10,
            timestamp: DateTime.utc(2026),
          )
        : await pending!.future;
  }

  @override
  Future<void> settings(ClientLocationAccess? access) async {
    settingsCalls++;
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest.cast<Map<String, dynamic>>()) {
      final loader = FontLoader(entry['family'] as String);
      for (final font
          in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  late RequestWorkflows workflows;
  late RequestLocations locations;
  late FakeAuthRepository auth;
  WeyonjeMap? map;
  setUp(() {
    workflows = RequestWorkflows();
    locations = RequestLocations();
    auth = FakeAuthRepository(
      onResolve: (_) async => const ResolvedSession(actor),
    );
    map = null;
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          workflowRepositoryProvider.overrideWithValue(workflows),
          clientLocationGatewayProvider.overrideWithValue(locations),
          mapSelectionProvider.overrideWithValue(
            const ConfiguredGoogleMapsGateway(),
          ),
          requestMapBuilderProvider.overrideWithValue((value) {
            map = value;
            return const SizedBox(
              height: 320,
              child: Center(child: Text('Map test surface')),
            );
          }),
        ],
        child: const WeyonjeApplication(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Request for a Service'), findsOneWidget);
    GoRouter.of(
      tester.element(find.text('Request for a Service')),
    ).push('/client/requests/new');
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  void selectToilet(WidgetTester tester) {
    tester
        .widget<WeyonjeSelect<String>>(find.byType(WeyonjeSelect<String>))
        .onChanged!('PIT_LATRINE');
    // Exercise the managed form field's validation value too.
    final field = find.descendant(
      of: find.byType(WeyonjeSelect<String>),
      matching: find.byWidgetPredicate((w) => w is FormField<String>),
    );
    for (final element in field.evaluate()) {
      final state = (element as StatefulElement).state;
      if (state is FormFieldState<String>) state.didChange('PIT_LATRINE');
    }
  }

  testWidgets('profile, exact field order, modes, ASAP and stable retry key', (
    tester,
  ) async {
    await open(tester);
    final labels = [
      'Client Details',
      'Client Name',
      'Phone Number',
      'Location Details',
      'Is the Weyonje Service Needed at Your Current Location?',
      'Yes',
      'No',
      'Service Location',
      'Service Details',
      'Type of Toilet to Empty',
      'Additional Contact Details',
      'Contact Person (Name)',
      'Contact Person (Telephone Contact)',
      'Submit Request',
    ];
    var previous = -double.infinity;
    for (final label in labels) {
      final y = tester.getTopLeft(find.text(label).last).dy;
      expect(y, greaterThanOrEqualTo(previous), reason: label);
      previous = y;
    }
    expect(find.text('Email Address'), findsNothing);
    expect(map!.hasDestination, false);
    await tap(tester, 'Yes');
    expect(map!.onSelected, isNull);
    expect(map!.destinationLatitude, 0.3);
    expect(locations.captures, 1);
    await tap(tester, 'Submit Request');
    expect(workflows.submissions, isEmpty);
    expect(find.text('Select the type of toilet to empty.'), findsOneWidget);
    selectToilet(tester);
    await tester.pumpAndSettle();
    await tap(tester, 'Submit Request');
    await tap(tester, 'Submit Request');
    expect(workflows.submissions.length, 2);
    expect(workflows.submissions[0], workflows.submissions[1]);
    expect(workflows.submissions[0]['scheduleMode'], 'ASAP');
    expect(workflows.submissions[0].containsKey('requestedServiceAt'), false);
    expect(workflows.submissions[0]['locationKind'], 'CURRENT');
    expect(workflows.submissions[0].containsKey('clientName'), false);
  });

  testWidgets('No confirms map coordinates and discards obsolete addresses', (
    tester,
  ) async {
    workflows.holdAddresses = true;
    await open(tester);
    await tap(tester, 'No');
    map!.onSelected!(const LatLng(1, 32));
    await tester.pump();
    map!.onSelected!(const LatLng(2, 33));
    await tester.pump();
    workflows.addresses[1].complete('Newest address');
    await tester.pump();
    workflows.addresses[0].complete('Obsolete address');
    await tester.pumpAndSettle();
    expect(find.text('Newest address'), findsOneWidget);
    expect(find.text('Obsolete address'), findsNothing);
    selectToilet(tester);
    await tester.pump();
    await tap(tester, 'Submit Request');
    expect(workflows.submissions, isEmpty);
    await tap(tester, 'Confirm Location');
    await tap(tester, 'Submit Request');
    expect(workflows.submissions.single['locationKind'], 'MAP_PIN');
    expect(workflows.submissions.single['location'], {
      'latitude': 2.0,
      'longitude': 33.0,
    });
    await tap(tester, 'Yes');
    expect(find.text('Newest address'), findsNothing);
    workflows.addresses.last.complete(null);
    await tester.pumpAndSettle();
    expect(find.textContaining('No address returned'), findsOneWidget);
  });

  testWidgets('unknown submission locks edits and retries the same command', (
    tester,
  ) async {
    workflows.failureCode = null;
    await open(tester);
    await tap(tester, 'Yes');
    selectToilet(tester);
    await tester.pumpAndSettle();
    await tap(tester, 'Submit Request');
    expect(find.text('Request Status Unconfirmed'), findsOneWidget);
    expect(map!.onSelected, isNull);
    await tap(tester, 'Submit Request');
    expect(workflows.submissions[0], workflows.submissions[1]);
  });

  testWidgets(
    'profile failure retries and contact pairing is field validated',
    (tester) async {
      workflows.profileFails = true;
      await open(tester);
      expect(find.text('Client Details Unavailable'), findsOneWidget);
      workflows.profileFails = false;
      await tap(tester, 'Retry Client Details');
      await tap(tester, 'Yes');
      selectToilet(tester);
      await tester.pumpAndSettle();
      final phone = find.byKey(const Key('request-contact-phone'));
      await tester.ensureVisible(phone);
      await tester.enterText(phone, '0700000123');
      await tap(tester, 'Submit Request');
      expect(
        find.text('Supply the contact name or clear the telephone contact.'),
        findsOneWidget,
      );
      expect(workflows.submissions, isEmpty);
      await tester.enterText(phone, '');
      final name = find.byKey(const Key('request-contact-name'));
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Amina');
      await tap(tester, 'Submit Request');
      expect(
        find.text('Enter the contact person’s telephone contact.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'mode change ignores late GPS and timeout never restores an old point',
    (tester) async {
      locations.pending = Completer<DevicePoint>();
      await open(tester);
      await tester.ensureVisible(find.text('Yes'));
      await tester.tap(find.text('Yes'));
      await tester.pump();
      await tester.ensureVisible(find.text('No'));
      await tester.tap(find.text('No'));
      await tester.pump();
      map!.onSelected!(const LatLng(1, 33));
      await tester.pump();
      locations.pending!.complete(
        DevicePoint(
          sampleId: 'late',
          latitude: 2,
          longitude: 34,
          accuracyMetres: 10,
          timestamp: DateTime.utc(2026),
        ),
      );
      await tester.pumpAndSettle();
      expect(map!.destinationLatitude, 1);
      locations.pending = Completer<DevicePoint>();
      await tester.ensureVisible(find.text('Yes'));
      await tester.tap(find.text('Yes'));
      await tester.pump();
      locations.pending!.completeError(TimeoutException('timeout'));
      await tester.pumpAndSettle();
      expect(map!.hasDestination, false);
      expect(
        find.textContaining('Getting your location timed out'),
        findsOneWidget,
      );
    },
  );

  for (final access in [
    ClientLocationAccess.servicesDisabled,
    ClientLocationAccess.denied,
    ClientLocationAccess.deniedForever,
  ]) {
    testWidgets('$access blocks submission and settings return retains draft', (
      tester,
    ) async {
      locations.access = access;
      await open(tester);
      expect(
        tester
            .widget<WeyonjeButton>(
              find.widgetWithText(WeyonjeButton, 'Submit Request'),
            )
            .onPressed,
        isNull,
      );
      final name = find.byKey(const Key('request-contact-name'));
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Contact draft');
      await tap(tester, 'Open Location Settings');
      expect(locations.settingsCalls, 1);
      locations.access = ClientLocationAccess.ready;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Contact draft'), findsOneWidget);
      expect(find.byType(RequestServiceScreen), findsOneWidget);
      expect(find.text('Location Access Required'), findsNothing);
    });
  }

  testWidgets(
    'warm resume keeps route, scroll, draft and fixed destination on transient failure',
    (tester) async {
      await open(tester);
      await tap(tester, 'Yes');
      final name = find.byKey(const Key('request-contact-name'));
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Saved in memory');
      final offset = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      final pending = Completer<AuthOutcome>();
      auth.onResolve = (_) => pending.future;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byType(RequestServiceScreen), findsOneWidget);
      pending.complete(const TransientAuthFailure('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Saved in memory'), findsOneWidget);
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        offset,
      );
      expect(locations.captures, 1);
      auth.onResolve = (_) async => const InvalidSession('revoked');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(RequestServiceScreen), findsNothing);
      expect(find.text('Welcome to Weyonje'), findsOneWidget);
    },
  );

  for (final layout in ['compact', 'large_text', 'keyboard', 'permission']) {
    testWidgets('request visual $layout', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });
      if (layout == 'permission') {
        locations.access = ClientLocationAccess.deniedForever;
      }
      workflows.profile = {
        'clientName': 'Kampala Test Organization',
        'phoneNumber': '+256700000123',
        'emailAddress': 'office@example.test',
      };
      await open(tester);
      if (layout == 'large_text') {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
      }
      if (layout == 'keyboard') {
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Contact Person (Name)'));
        await tester.pumpAndSettle();
      }
      if (layout == 'permission') {
        await tester.ensureVisible(find.text('Location Access Required'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Email Address'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(WeyonjeApplication),
        matchesGoldenFile('visual/goldens/request_$layout.png'),
      );
    });
  }
}
