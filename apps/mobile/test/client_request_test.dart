import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:weyonje/core/config/app_config.dart';
import 'package:weyonje/core/auth/session_credentials.dart';
import 'auth_repository_test.dart' show MemorySessionStore, credentialsJson;
import 'support/client_request_http_adapter.dart';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
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

const savedRequestJson = <String, Object?>{
  'id': 'saved',
  'reference': 'WRQ-LEGACY123456',
  'origin': 'MOBILE_APP',
  'status': 'PENDING',
  'locationLabel': '0.400000, 32.600000',
  'locationKind': 'CURRENT',
  'location': {'latitude': 0.4, 'longitude': 32.6},
  'toiletType': 'SEPTIC_TANK',
  'additionalContactName': 'Saved Contact',
  'additionalContactPhone': '+256700000123',
  'scheduleMode': 'SCHEDULED',
  'requestedServiceAt': '2026-01-02T12:00:00.000Z',
  'updatedAt': '2026-01-01T12:00:00.000Z',
  'createdAt': '2026-01-01T12:00:00.000Z',
  'clientName': 'Amina Test',
};

class RequestWorkflows extends Fake implements WorkflowRepository {
  Map<String, dynamic> profile = {
    'clientName': 'Amina Test',
    'phoneNumber': '+256700000123',
  };
  bool profileFails = false;
  bool listFails = false;
  int listCalls = 0;
  @override
  Future<List<ServiceRequestSummary>> clientRequests() async {
    listCalls++;
    if (listFails) throw const WorkflowException("List unavailable");
    return [];
  }

  WorkflowRepository? wireRepository;
  Completer<ServiceRequestDetail>? pendingSubmission;
  ServiceRequestDetail? created;
  String? failureCode = 'INVALID_REQUEST';
  final submissions = <Map<String, Object?>>[];
  final updates = <Map<String, Object?>>[];
  final withdrawals = <Map<String, Object?>>[];
  WorkflowException? mutationFailure;
  @override
  Future<ServiceRequestDetail> updateClientRequest(
    String id,
    Map<String, Object?> data,
  ) async {
    updates.add(data);
    if (mutationFailure != null) throw mutationFailure!;
    return created!;
  }

  @override
  Future<ServiceRequestDetail> withdrawClientRequest(
    String id,
    Map<String, Object?> data,
  ) async {
    withdrawals.add(data);
    if (mutationFailure != null) throw mutationFailure!;
    created = ServiceRequestDetail.fromJson({
      ...savedRequestJson,
      'status': 'CANCELLED',
    });
    return created!;
  }

  int geocodeCalls = 0;
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
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    geocodeCalls++;
    throw StateError('Client selection must not geocode');
  }

  @override
  Future<ServiceRequestDetail> clientRequest(String id) async => created!;

  @override
  Future<ServiceRequestDetail> createClientRequest(
    Map<String, Object?> data,
  ) async {
    submissions.add(data);
    if (wireRepository != null) {
      return created = await wireRepository!.createClientRequest(data);
    }
    if (pendingSubmission != null) return pendingSubmission!.future;
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
  WeyonjeMap? pickerMap;
  setUp(() {
    workflows = RequestWorkflows();
    locations = RequestLocations();
    auth = FakeAuthRepository(
      onResolve: (_) async => const ResolvedSession(actor),
    );
    map = null;
  });

  Future<void> open(
    WidgetTester tester, {
    String route = '/client/requests/new',
  }) async {
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
            if (value.height == null) {
              pickerMap = value;
            } else {
              map = value;
            }
            return SizedBox(
              height: value.height,
              child: const Center(child: Text('Map test surface')),
            );
          }),
        ],
        child: const WeyonjeApplication(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Request for a Service'), findsOneWidget);
    GoRouter.of(tester.element(find.text('Request for a Service'))).push(route);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  for (final mode in ['CURRENT', 'MAP_PIN']) {
    testWidgets(
      'edit prepopulates $mode once and preserves draft on resume and My Requests return',
      (tester) async {
        workflows.created = ServiceRequestDetail.fromJson({
          ...savedRequestJson,
          'locationKind': mode,
        });
        await open(tester, route: '/client/requests/saved/edit');
        expect(map!.destinationLatitude, 0.4);
        expect(map!.destinationLongitude, 32.6);
        expect(locations.captures, 0);
        expect(
          tester
              .widget<WeyonjeSelect<String>>(find.byType(WeyonjeSelect<String>))
              .initialValue,
          'SEPTIC_TANK',
        );
        final name = find.byKey(const Key('request-contact-name'));
        await tester.ensureVisible(name);
        await tester.enterText(name, 'Changed Contact');
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        await tap(tester, 'Check My Requests');
        await tap(tester, 'Return to Request');
        expect(find.text('Changed Contact'), findsOneWidget);
        expect(locations.captures, 0);
        await tap(tester, 'Save Changes');
        expect(workflows.updates.single, containsPair('locationKind', mode));
        expect(
          workflows.updates.single,
          containsPair('additionalContactName', 'Changed Contact'),
        );
        expect(workflows.updates.single, isNot(contains('scheduleMode')));
        expect(workflows.updates.single, isNot(contains('requestedServiceAt')));
        expect(
          workflows.updates.single,
          containsPair('expectedUpdatedAt', savedRequestJson['updatedAt']),
        );
        expect(workflows.submissions, isEmpty);
      },
    );
  }

  testWidgets(
    'uncertain edit holds draft and same key across HTTP conflict and empty list',
    (tester) async {
      workflows.created = ServiceRequestDetail.fromJson(savedRequestJson);
      workflows.mutationFailure = const WorkflowException(
        'Timeout',
        code: 'REQUEST_TIMEOUT',
      );
      await open(tester, route: '/client/requests/saved/edit');
      await tap(tester, 'Save Changes');
      await tap(tester, 'Check My Requests');
      await tap(tester, 'Return to Request');
      workflows.mutationFailure = const WorkflowException(
        'Conflict',
        code: 'CONFLICT',
      );
      await tap(tester, 'Save Changes');
      expect(workflows.updates[1], workflows.updates[0]);
      workflows.mutationFailure = null;
      await tap(tester, 'Save Changes');
      expect(workflows.updates[2], workflows.updates[0]);
    },
  );

  testWidgets(
    'stale edit preserves draft, blocks overwrite and offers latest details',
    (tester) async {
      workflows.created = ServiceRequestDetail.fromJson(savedRequestJson);
      workflows.mutationFailure = const WorkflowException(
        'Request changed',
        code: 'CONFLICT',
      );
      await open(tester, route: '/client/requests/saved/edit');
      await tap(tester, 'Save Changes');
      expect(
        tester
            .widget<WeyonjeButton>(
              find.ancestor(
                of: find.text('Save Changes'),
                matching: find.byType(WeyonjeButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await tap(tester, 'View Latest Request Details');
      expect(find.text('Request Details'), findsOneWidget);
      expect(workflows.updates, hasLength(1));
    },
  );

  testWidgets('edit clears both contacts explicitly; Back saves nothing', (
    tester,
  ) async {
    workflows.created = ServiceRequestDetail.fromJson(savedRequestJson);
    await open(tester, route: '/client/requests/saved/edit');
    for (final key in ['request-contact-name', 'request-contact-phone']) {
      final field = find.byKey(Key(key));
      await tester.ensureVisible(field);
      await tester.enterText(field, '');
    }
    await tap(tester, 'Save Changes');
    expect(
      workflows.updates.single,
      containsPair('additionalContactName', null),
    );
    expect(
      workflows.updates.single,
      containsPair('additionalContactPhone', null),
    );
    GoRouter.of(
      tester.element(find.text('Request Details')),
    ).push('/client/requests/saved/edit');
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('Request for a Service'))).pop();
    await tester.pumpAndSettle();
    expect(workflows.updates, hasLength(1));
  });

  testWidgets(
    'saved details need no location permission and withdrawal confirmation can cancel or retry',
    (tester) async {
      workflows.created = ServiceRequestDetail.fromJson(savedRequestJson);
      locations.access = ClientLocationAccess.deniedForever;
      await open(tester, route: '/client/requests/saved');
      expect(map!.showDeviceLocation, isFalse);
      expect(map!.interactive, isFalse);
      expect(map!.destinationLatitude, 0.4);
      expect(locations.checks, 0);
      await tap(tester, 'Delete Request');
      await tap(tester, 'Keep Request');
      expect(workflows.withdrawals, isEmpty);
      workflows.mutationFailure = const WorkflowException(
        'Timeout',
        code: 'REQUEST_TIMEOUT',
      );
      await tap(tester, 'Delete Request');
      await tap(tester, 'Delete Request');
      workflows.mutationFailure = const WorkflowException(
        'Conflict',
        code: 'CONFLICT',
      );
      await tap(tester, 'Retry Delete Request');
      expect(workflows.withdrawals[1], workflows.withdrawals[0]);
      workflows.mutationFailure = null;
      await tap(tester, 'Retry Delete Request');
      expect(workflows.withdrawals[2], workflows.withdrawals[0]);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Edit Request'), findsNothing);
    },
  );

  testWidgets(
    'historical text-only details never invent values and linked Call Centre cannot edit',
    (tester) async {
      workflows.created = ServiceRequestDetail.fromJson({
        ...savedRequestJson,
        'origin': 'CALL_CENTRE',
        'locationKind': 'TEXT',
        'location': null,
        'toiletType': null,
        'additionalContactPhone': null,
      });
      await open(tester, route: '/client/requests/saved');
      expect(map, isNull);
      expect(find.text('Saved Map Unavailable'), findsOneWidget);
      expect(find.text('Not recorded'), findsNWidgets(2));
      expect(find.text('Edit Request'), findsNothing);
      expect(find.text('Delete Request'), findsNothing);
      expect(locations.checks, 0);
    },
  );

  for (final screen in ['dashboard', 'details', 'edit', 'dialog']) {
    for (final layout in ['compact', 'large_text', 'landscape']) {
      testWidgets('Client management visual $screen $layout', (tester) async {
        tester.view.physicalSize = layout == 'landscape'
            ? const Size(740, 360)
            : const Size(360, 740);
        tester.view.devicePixelRatio = 1;
        if (layout == 'large_text') {
          tester.platformDispatcher.textScaleFactorTestValue = 2;
        }
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetViewInsets();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        workflows.created = ServiceRequestDetail.fromJson(savedRequestJson);
        await open(
          tester,
          route: screen == 'edit'
              ? '/client/requests/saved/edit'
              : '/client/requests/saved',
        );
        if (screen == 'dashboard') {
          GoRouter.of(tester.element(find.text('Request Details'))).pop();
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Recent Requests'));
          await tester.pumpAndSettle();
        }
        if (screen == 'edit') {
          await tester.ensureVisible(find.text('Save Changes'));
          await tester.pumpAndSettle();
        }
        if (screen == 'dialog') await tap(tester, 'Delete Request');
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(WeyonjeApplication),
          matchesGoldenFile('visual/goldens/client_${screen}_$layout.png'),
        );
        if (screen == 'dialog') {
          // The scrollable dialog must keep both actions reachable at 2x text
          // and in landscape, even when initially below the viewport.
          await tester.ensureVisible(find.text('Keep Request'));
          await tester.pumpAndSettle();
          await expectLater(
            find.byType(WeyonjeApplication),
            matchesGoldenFile(
              'visual/goldens/client_dialog_actions_$layout.png',
            ),
          );
          await tap(tester, 'Keep Request');
          expect(workflows.withdrawals, isEmpty);
        }
      });
    }
  }

  void selectToilet(WidgetTester tester, [String toilet = 'PIT_LATRINE']) {
    tester
        .widget<WeyonjeSelect<String>>(find.byType(WeyonjeSelect<String>))
        .onChanged!(toilet);
    // Exercise the managed form field's validation value too.
    final field = find.descendant(
      of: find.byType(WeyonjeSelect<String>),
      matching: find.byWidgetPredicate((w) => w is FormField<String>),
    );
    for (final element in field.evaluate()) {
      final state = (element as StatefulElement).state;
      if (state is FormFieldState<String>) state.didChange(toilet);
    }
  }

  for (final mode in ['CURRENT', 'MAP_PIN']) {
    for (final toilet in ['PIT_LATRINE', 'SEPTIC_TANK']) {
      testWidgets('wire payload and confirmed details: $mode / $toilet', (
        tester,
      ) async {
        final adapter = ClientRequestHttpAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        workflows.wireRepository = NativeWorkflowRepository(
          const AppConfig(apiBaseUrl: 'https://api.example.test'),
          MemorySessionStore(
            SessionCredentials.fromJson(credentialsJson(suffix: 'test')),
          ),
          dio,
        );
        await open(tester);
        await tap(tester, mode == 'CURRENT' ? 'Yes' : 'No');
        if (mode == 'MAP_PIN') {
          await tap(tester, 'Select Location on Map');
          pickerMap!.onSelected!(const LatLng(0.312345678, 32.512345678));
          await tester.pumpAndSettle();
        }
        selectToilet(tester, toilet);
        await tester.pumpAndSettle();
        if (toilet == 'SEPTIC_TANK') {
          final name = find.byKey(const Key('request-contact-name'));
          await tester.ensureVisible(name);
          await tester.enterText(name, ' Contact ');
          final phone = find.byKey(const Key('request-contact-phone'));
          await tester.ensureVisible(phone);
          await tester.enterText(phone, ' 0700000123 ');
        }
        await tap(tester, 'Submit Request');
        final wire = adapter.payloads.single;
        expect(wire.keys.toSet(), {
          'locationKind',
          'location',
          'toiletType',
          'scheduleMode',
          'idempotencyKey',
          if (toilet == 'SEPTIC_TANK') 'additionalContactName',
          if (toilet == 'SEPTIC_TANK') 'additionalContactPhone',
        });
        if (toilet == 'SEPTIC_TANK') {
          expect(wire['additionalContactName'], 'Contact');
          expect(wire['additionalContactPhone'], '0700000123');
        }
        expect(
          wire['idempotencyKey'],
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
        expect(wire['locationKind'], mode);
        expect(wire['toiletType'], toilet);
        expect(wire['scheduleMode'], 'AS_SOON_AS_POSSIBLE');
        expect((wire['location'] as Map)['latitude'], isA<num>());
        expect((wire['location'] as Map)['longitude'], isA<num>());
        expect(find.text('Request Details'), findsOneWidget);
        expect(find.text('Pending'), findsOneWidget);
        expect(find.text('As soon as possible'), findsOneWidget);
      });
    }
  }

  testWidgets('duplicate submit is blocked; timeout holds the same key', (
    tester,
  ) async {
    workflows.pendingSubmission = Completer<ServiceRequestDetail>();
    await open(tester);
    await tap(tester, 'Yes');
    selectToilet(tester);
    await tester.pumpAndSettle();
    final submit = tester
        .widget<WeyonjeButton>(
          find.widgetWithText(WeyonjeButton, 'Submit Request'),
        )
        .onPressed!;
    submit();
    submit();
    await tester.pump();
    expect(workflows.submissions, hasLength(1));
    expect(
      tester
          .widget<WeyonjeButton>(
            find.widgetWithText(WeyonjeButton, 'Check My Requests'),
          )
          .onPressed,
      isNull,
    );
    workflows.pendingSubmission!.completeError(
      const WorkflowException('Response timed out.', code: 'REQUEST_TIMEOUT'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Request Status Unconfirmed'), findsOneWidget);
    workflows.pendingSubmission = null;
    workflows.wireRepository = NativeWorkflowRepository(
      const AppConfig(apiBaseUrl: 'https://api.example.test'),
      MemorySessionStore(
        SessionCredentials.fromJson(credentialsJson(suffix: 'test')),
      ),
      Dio()..httpClientAdapter = ClientRequestHttpAdapter(),
    );
    await tap(tester, 'Submit Request');
    expect(workflows.submissions[0], workflows.submissions[1]);
    expect(find.text('Request Details'), findsOneWidget);
  });

  testWidgets(
    'profile text boxes are read-only, wrap long values and never open the keyboard',
    (tester) async {
      workflows.profile = {
        'clientName':
            'A long organization name that must wrap at compact widths without losing any readable content',
        'phoneNumber': '+256700000123',
        'emailAddress': 'long-office-address@example.test',
      };
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await open(tester);
      for (final label in ['Client Name', 'Phone Number', 'Email Address']) {
        final field = find.ancestor(
          of: find.text(label),
          matching: find.byType(FTextField),
        );
        expect(tester.widget<FTextField>(field).readOnly, isTrue);
        final editable = find.descendant(
          of: field,
          matching: find.byType(EditableText),
        );
        expect(tester.widget<EditableText>(editable).readOnly, isTrue);
        await tester.ensureVisible(editable);
        await tester.tap(editable);
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final outcome in [
    'before',
    'validation',
    'INVALID_REQUEST',
    'UNEXPECTED_ERROR',
  ]) {
    for (final listFails in [false, true]) {
      testWidgets(
        'Check My Requests retains draft and retry state: $outcome / list failure $listFails',
        (tester) async {
          workflows.listFails = listFails;
          await open(tester);
          expect(find.text('Check My Requests'), findsOneWidget);
          await tap(tester, 'Yes');
          if (outcome != 'before') {
            if (outcome != 'validation') selectToilet(tester);
            workflows.failureCode = outcome;
            await tester.pumpAndSettle();
            await tap(tester, 'Submit Request');
          }
          final count = workflows.submissions.length;
          final submit = tester
              .widget<WeyonjeButton>(
                find.widgetWithText(WeyonjeButton, 'Submit Request'),
              )
              .onPressed!;
          final check = tester
              .widget<WeyonjeButton>(
                find.widgetWithText(WeyonjeButton, 'Check My Requests'),
              )
              .onPressed!;
          check();
          check();
          submit();
          await tester.pumpAndSettle();
          expect(workflows.submissions.length, count);
          expect(workflows.listCalls, 1);
          expect(find.text('My Requests'), findsOneWidget);
          if (listFails) {
            GoRouter.of(tester.element(find.text('My Requests'))).pop();
            await tester.pumpAndSettle();
          } else {
            await tap(tester, 'Return to Request');
          }
          expect(find.byType(RequestServiceScreen), findsOneWidget);
          expect(find.text('Check My Requests'), findsOneWidget);
          expect(
            find.textContaining('Submission may have succeeded.'),
            findsNothing,
          );
          if (outcome == 'UNEXPECTED_ERROR') {
            expect(find.text('Request Status Unconfirmed'), findsOneWidget);
            expect(
              tester
                  .widget<FTextFormField>(
                    find.byKey(const Key('request-contact-name')),
                  )
                  .enabled,
              isFalse,
            );
            await tap(tester, 'Submit Request');
            expect(workflows.submissions[0], workflows.submissions[1]);
          } else {
            expect(find.text('Request Status Unconfirmed'), findsNothing);
          }
        },
      );
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
      'Check My Requests',
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
    expect(workflows.submissions[0]['scheduleMode'], 'AS_SOON_AS_POSSIBLE');
    expect(workflows.submissions[0].containsKey('requestedServiceAt'), false);
    expect(workflows.submissions[0]['locationKind'], 'CURRENT');
    expect(workflows.submissions[0].containsKey('clientName'), false);
  });

  testWidgets(
    'map tap returns immediately; cancellation and stale taps preserve draft',
    (tester) async {
      await open(tester);
      await tap(tester, 'No');
      expect(
        tester.getTopLeft(find.text('Select Location on Map')).dy,
        lessThan(tester.getTopLeft(find.text('Map test surface').last).dy),
      );
      expect(map!.interactive, false);
      expect(map!.onSelected, isNull);
      await tap(tester, 'Select Location on Map');
      expect(pickerMap!.height, isNull);
      final staleTap = pickerMap!.onSelected!;
      staleTap(const LatLng(2.123456789, 33.123456789));
      await tester.pumpAndSettle();
      expect(find.text('Request for a Service'), findsOneWidget);
      expect(find.text('2.123457, 33.123457'), findsOneWidget);
      staleTap(const LatLng(3, 34));
      await tester.pumpAndSettle();
      expect(map!.destinationLatitude, 2.123456789);
      selectToilet(tester);
      await tester.pumpAndSettle();
      final name = find.byKey(const Key('request-contact-name'));
      await tester.ensureVisible(name);
      await tester.enterText(name, ' Draft contact ');
      final phone = find.byKey(const Key('request-contact-phone'));
      await tester.ensureVisible(phone);
      await tester.enterText(phone, '0700000123');
      await tap(tester, 'Select Location on Map');
      expect(map!.destinationLatitude, 2.123456789);
      final cancelledTap = pickerMap!.onSelected!;
      await tester.tap(find.byTooltip('Close Map'));
      await tester.pumpAndSettle();
      cancelledTap(const LatLng(4, 35));
      await tester.pumpAndSettle();
      expect(find.text(' Draft contact '), findsOneWidget);
      expect(map!.destinationLatitude, 2.123456789);
      await tap(tester, 'Submit Request');
      expect(workflows.submissions.single['locationKind'], 'MAP_PIN');
      expect(workflows.submissions.single['location'], {
        'latitude': 2.123456789,
        'longitude': 33.123456789,
      });
      expect(
        workflows.submissions.single['additionalContactName'],
        'Draft contact',
      );
      expect(workflows.submissions.single.containsKey('locationText'), false);
      for (final label in [
        'Reload Map',
        'Choose Location in Full Screen',
        'Confirm Location',
        'Retry Address',
      ]) {
        expect(find.text(label), findsNothing);
      }
      expect(workflows.geocodeCalls, 0);
    },
  );

  testWidgets(
    'permission failure or rejected retry cannot erase an earlier unknown outcome',
    (tester) async {
      workflows.failureCode = 'UNEXPECTED_ERROR';
      await open(tester);
      await tap(tester, 'Yes');
      selectToilet(tester);
      await tester.pumpAndSettle();
      await tap(tester, 'Submit Request');
      locations.access = ClientLocationAccess.denied;
      await tap(tester, 'Submit Request');
      expect(find.text('Request Status Unconfirmed'), findsOneWidget);
      expect(workflows.submissions, hasLength(1));
      locations.access = ClientLocationAccess.ready;
      await tap(tester, 'Retry Location Access');
      workflows.failureCode = 'INVALID_REQUEST';
      await tap(tester, 'Submit Request');
      expect(find.text('Request Status Unconfirmed'), findsOneWidget);
      expect(workflows.submissions[0], workflows.submissions[1]);
      expect(
        tester
            .widget<FTextFormField>(
              find.byKey(const Key('request-contact-name')),
            )
            .enabled,
        isFalse,
      );
    },
  );

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
      await tap(tester, 'Select Location on Map');
      pickerMap!.onSelected!(const LatLng(1, 33));
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

  testWidgets('dismissed picker ignores callbacks after logout', (
    tester,
  ) async {
    await open(tester);
    await tap(tester, 'No');
    await tap(tester, 'Select Location on Map');
    final callback = pickerMap!.onSelected!;
    auth.onResolve = (_) async => const InvalidSession('revoked');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    callback(const LatLng(1, 33));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Weyonje'), findsOneWidget);
    expect(workflows.submissions, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('coordinate accessibility entry returns directly', (
    tester,
  ) async {
    await open(tester);
    await tap(tester, 'No');
    await tap(tester, 'Select Location on Map');
    await tester.tap(find.byTooltip('Enter Coordinates'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).at(0), '1.23456789');
    await tester.enterText(find.byType(EditableText).at(1), '32.98765432');
    await tap(tester, 'Use Entered Coordinates');
    expect(find.text('Request for a Service'), findsOneWidget);
    expect(find.text('1.234568, 32.987654'), findsOneWidget);
    expect(map!.destinationLatitude, 1.23456789);
  });

  for (final layout in [
    'compact',
    'large_text',
    'landscape',
    'permission',
    'coordinates',
  ]) {
    testWidgets('picker visual and layout $layout', (tester) async {
      tester.view.physicalSize = layout == 'landscape'
          ? const Size(740, 360)
          : const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });
      await open(tester);
      await tap(tester, 'No');
      await tap(tester, 'Select Location on Map');
      if (layout == 'large_text') {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
      }
      expect(pickerMap!.height, isNull);
      expect(find.byType(SingleChildScrollView), findsNothing);
      if (layout == 'permission') {
        locations.access = ClientLocationAccess.deniedForever;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Location access is required'),
          findsOneWidget,
        );
      }
      if (layout == 'coordinates') {
        await tester.tap(find.byTooltip('Enter Coordinates'));
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        await tap(tester, 'Use Entered Coordinates');
        expect(
          find.text('Enter valid latitude and longitude values.'),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(WeyonjeApplication),
        matchesGoldenFile('visual/goldens/picker_$layout.png'),
      );
    });
  }

  for (final layout in [
    'compact',
    'large_text',
    'keyboard',
    'map',
    'actions',
    'uncertain',
    'permission',
    'landscape',
  ]) {
    testWidgets('request visual $layout', (tester) async {
      tester.view.physicalSize = layout == 'landscape'
          ? const Size(740, 360)
          : const Size(360, 740);
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
      if (layout == 'map') {
        await tap(tester, 'No');
        await tester.ensureVisible(find.text('Select Location on Map'));
        await tester.pumpAndSettle();
      }
      if (layout == 'actions' || layout == 'uncertain') {
        if (layout == 'uncertain') {
          workflows.failureCode = 'UNEXPECTED_ERROR';
          await tap(tester, 'Yes');
          selectToilet(tester);
          await tester.pumpAndSettle();
          await tap(tester, 'Submit Request');
        }
        await tester.ensureVisible(find.text('Check My Requests'));
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
