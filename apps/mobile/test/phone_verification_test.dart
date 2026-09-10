import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:weyonje/core/auth/auth_providers.dart';
import 'package:weyonje/core/auth/auth_repository.dart';
import 'package:weyonje/core/auth/current_actor.dart';
import 'package:weyonje/core/auth/registration_models.dart';
import 'package:weyonje/core/auth/sms_retriever.dart';
import 'package:weyonje/features/auth/application/launch_controller.dart';
import 'package:weyonje/features/auth/application/registration_controller.dart';
import 'package:weyonje/features/auth/presentation/phone_verification_screen.dart';
import 'package:weyonje/theme/theme.dart';
import 'package:weyonje/ui/weyonje_otp_field.dart';
import 'support/fake_auth_repository.dart';

const initialId = '73f3d97e-0f93-445d-bdbe-77abac7b42ac';
const nextId = '73f3d97e-0f93-445d-bdbe-77abac7b42ad';
PhoneChallenge challenge([String id = initialId]) => PhoneChallenge(
  id: id,
  maskedPhone: '+256 •••••• 123',
  expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
  resendAvailableAt: DateTime.now().toUtc(),
  deliveryStatus: PhoneCodeDeliveryStatus.sent,
);
const success = ResolvedSession(
  CurrentActor(actorType: ActorType.client, access: ActorAccess.eligible),
);

class FakeRetrieval extends SmsRetrieval {
  int starts = 0;
  int stops = 0;
  @override
  Future<void> start() async {
    starts++;
    candidate = null;
  }

  @override
  Future<void> stop() async {
    stops++;
    candidate = null;
  }

  void receive(String id, String code) {
    candidate = SmsCandidate(id, code);
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  Future<ProviderContainer> render(
    WidgetTester tester,
    FakeAuthRepository repository, {
    SmsRetrieval? retrieval,
    PhoneChallenge? initialChallenge,
    PhoneVerificationPurpose purpose = PhoneVerificationPurpose.clientSignIn,
    double scale = 1,
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          if (retrieval != null)
            smsRetrievalProvider.overrideWithValue(retrieval),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: FLocalizations.localizationsDelegates,
          supportedLocales: FLocalizations.supportedLocales,
          theme: lightTheme.toApproximateMaterialTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: FTheme(data: lightTheme, child: child!),
          ),
          home: PhoneVerificationScreen(
            arguments: PhoneVerificationArguments(
              challenge: initialChallenge ?? challenge(),
              purpose: purpose,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PhoneVerificationScreen)),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
    });
    return container;
  }

  for (final purpose in PhoneVerificationPurpose.values) {
    testWidgets('$purpose ignores legacy response code on entry and resend', (
      tester,
    ) async {
      PhoneChallenge legacy(String id) => PhoneChallenge.fromJson({
        'challengeId': id,
        'maskedPhone': '+256 •••••• 123',
        'expiresAt': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 10))
            .toIso8601String(),
        'resendAvailableAt': DateTime.now().toUtc().toIso8601String(),
        'deliveryStatus': 'SENT',
        'developmentVerificationCode': '001234',
      });
      final repository = FakeAuthRepository(
        onResolve: (_) async => const NoStoredSession(),
        onResendClientCode: (_, _) async => ChallengeCreated(legacy(nextId)),
        onResendRegistrationCode: (_, _) async =>
            ChallengeCreated(legacy(nextId)),
      );
      final container = await render(
        tester,
        repository,
        purpose: purpose,
        initialChallenge: legacy(initialId),
      );
      for (var i = 0; i < 2; i++) {
        await tester.pump(const Duration(seconds: 2));
        expect(
          tester
              .widget<WeyonjeOtpField>(find.byType(WeyonjeOtpField))
              .controller
              .text,
          isEmpty,
        );
        expect(
          repository.verifyClientCodeCalls + repository.verifyRegistrationCalls,
          0,
        );
        expect(
          container.read(launchControllerProvider),
          isNot(isA<LaunchAuthenticated>()),
        );
        expect(find.textContaining('Development SMS mode'), findsNothing);
        if (i == 0) {
          await tester.tap(find.byKey(const Key('resend-phone-code')));
          await tester.pumpAndSettle();
        }
      }
    });

    for (final early in [false, true]) {
      testWidgets(
        '$purpose accepts matching platform SMS exactly once, early=$early',
        (tester) async {
          const channel = MethodChannel('weyonje/sms_retriever');
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(channel, (_) async => null);
          final retrieval = SmsRetrieval();
          addTearDown(() {
            retrieval.dispose();
            messenger.setMockMethodCallHandler(channel, null);
          });
          await retrieval.start();
          Future<void> sms(String id, String code, int generation) async {
            await messenger.handlePlatformMessage(
              channel.name,
              const StandardMethodCodec().encodeMethodCall(
                MethodCall('candidate', {
                  'challengeId': id,
                  'code': code,
                  'generation': generation,
                }),
              ),
              (_) {},
            );
          }

          final calls = <String>[];
          Future<AuthOutcome> verify(String id, String code, Object _) async {
            calls.add('$id:$code');
            return const CancelledSignIn();
          }

          final repository = FakeAuthRepository(
            onResolve: (_) async => const NoStoredSession(),
            onVerifyClientCode: verify,
            onVerifyRegistration: verify,
          );
          if (early) {
            // The listener is active before the HTTP challenge response / screen.
            await sms(initialId, '001234', retrieval.generation);
            await sms(nextId, '111111', retrieval.generation);
          }
          await render(
            tester,
            repository,
            purpose: purpose,
            retrieval: retrieval,
          );
          if (!early) {
            await sms(initialId, '999999', retrieval.generation - 1);
            await sms(nextId, '111111', retrieval.generation);
            await tester.pump();
            expect(calls, isEmpty);
            expect(
              tester
                  .widget<WeyonjeOtpField>(find.byType(WeyonjeOtpField))
                  .controller
                  .text,
              isEmpty,
            );
            await sms(initialId, '001234', retrieval.generation);
          }
          await tester.pump();
          await sms(initialId, '001234', retrieval.generation);
          await sms(nextId, '222222', retrieval.generation);
          await tester.pump();
          expect(calls, ['$initialId:001234']);
          expect(
            tester
                .widget<WeyonjeOtpField>(find.byType(WeyonjeOtpField))
                .controller
                .text,
            '001234',
          );
          await tester.enterText(
            find.byKey(const Key('verification-code')),
            '00123',
          );
          await sms(initialId, '001234', retrieval.generation);
          await tester.pump();
          expect(
            tester
                .widget<WeyonjeOtpField>(find.byType(WeyonjeOtpField))
                .controller
                .text,
            '00123',
          );
          expect(calls, ['$initialId:001234']);
        },
      );
    }

    testWidgets(
      '$purpose deliberate clipboard paste preserves leading zeroes',
      (tester) async {
        String? sent;
        Future<AuthOutcome> verify(String _, String code, Object token) async {
          sent = code;
          return const CancelledSignIn();
        }

        final repository = FakeAuthRepository(
          onResolve: (_) async => const NoStoredSession(),
          onVerifyClientCode: verify,
          onVerifyRegistration: verify,
        );
        await render(tester, repository, purpose: purpose);
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.getData') return {'text': '001234'};
          return null;
        });
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );
        final editable = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        await editable.pasteText(SelectionChangedCause.toolbar);
        await tester.pump();
        expect(sent, '001234');
        expect(
          repository.verifyClientCodeCalls + repository.verifyRegistrationCalls,
          1,
        );
      },
    );
    testWidgets(
      '$purpose submits leading-zero input once and shows success before routing',
      (tester) async {
        final pending = Completer<AuthOutcome>();
        String? sent;
        Future<AuthOutcome> verify(String id, String code, Object _) {
          sent = code;
          return pending.future;
        }

        final repository = FakeAuthRepository(
          onResolve: (_) async => const NoStoredSession(),
          onVerifyClientCode: verify,
          onVerifyRegistration: verify,
        );
        final container = await render(tester, repository, purpose: purpose);
        await tester.enterText(
          find.byKey(const Key('verification-code')),
          '00123',
        );
        expect(sent, isNull);
        await tester.enterText(
          find.byKey(const Key('verification-code')),
          '001234',
        );
        await tester.pump();
        expect(sent, '001234');
        expect(find.text('Checking Code'), findsOneWidget);
        await container
            .read(phoneVerificationControllerProvider(initialId).notifier)
            .verify(
              PhoneVerificationArguments(
                challenge: challenge(),
                purpose: purpose,
              ),
              '001234',
            );
        expect(
          repository.verifyClientCodeCalls + repository.verifyRegistrationCalls,
          1,
        );
        pending.complete(success);
        await tester.pump();
        expect(
          tester.widget<WeyonjeOtpField>(find.byType(WeyonjeOtpField)).verified,
          isTrue,
        );
        expect(
          container.read(launchControllerProvider),
          isNot(isA<LaunchAuthenticated>()),
        );
        await tester.pump(const Duration(milliseconds: 700));
        expect(
          container.read(launchControllerProvider),
          isA<LaunchAuthenticated>(),
        );
      },
    );
  }

  testWidgets(
    'wrong code resets on edit; unchanged value never loops; network failure is distinct',
    (tester) async {
      final repository = FakeAuthRepository(
        onResolve: (_) async => const NoStoredSession(),
        onVerifyClientCode: (_, code, _) async => code == '001234'
            ? const CodeVerificationFailure(
                CodeFailureKind.invalid,
                'Check your code.',
              )
            : const TransientAuthFailure('Connection interrupted.'),
      );
      await render(tester, repository);
      await tester.enterText(
        find.byKey(const Key('verification-code')),
        '001234',
      );
      await tester.pump();
      expect(
        tester.widget<WeyonjeOtpField>(find.byType(WeyonjeOtpField)).invalid,
        isTrue,
      );
      await tester.enterText(
        find.byKey(const Key('verification-code')),
        '001234',
      );
      await tester.pump();
      expect(repository.verifyClientCodeCalls, 1);
      await tester.enterText(
        find.byKey(const Key('verification-code')),
        '00123',
      );
      await tester.pump();
      expect(
        tester.widget<WeyonjeOtpField>(find.byType(WeyonjeOtpField)).invalid,
        isFalse,
      );
      await tester.enterText(
        find.byKey(const Key('verification-code')),
        '001235',
      );
      await tester.pump();
      expect(find.text('Connection interrupted.'), findsOneWidget);
      expect(
        tester.widget<WeyonjeOtpField>(find.byType(WeyonjeOtpField)).invalid,
        isFalse,
      );
      expect(find.text('Retry Verification'), findsOneWidget);
    },
  );

  testWidgets(
    'resend buffers early autofill and discards an obsolete reference',
    (tester) async {
      final retrieval = FakeRetrieval();
      final replacement = Completer<ChallengeOutcome>();
      final calls = <String>[];
      final repository = FakeAuthRepository(
        onResolve: (_) async => const NoStoredSession(),
        onResendClientCode: (_, _) => replacement.future,
        onVerifyClientCode: (id, code, _) async {
          calls.add('$id:$code');
          return const CancelledSignIn();
        },
      );
      await render(tester, repository, retrieval: retrieval);
      await tester.tap(find.byKey(const Key('resend-phone-code')));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(retrieval.starts, 1);
      retrieval.receive(initialId, '111111');
      retrieval.receive(nextId, '001234');
      expect(calls, isEmpty);
      replacement.complete(ChallengeCreated(challenge(nextId)));
      await tester.pump();
      expect(calls, ['$nextId:001234']);
      retrieval.receive(initialId, '222222');
      await tester.pump();
      expect(calls.length, 1);
      await tester.pumpWidget(const SizedBox());
      expect(retrieval.stops, greaterThan(0));
    },
  );

  testWidgets(
    'leaving ignores verification response and cancels success transition',
    (tester) async {
      final pending = Completer<AuthOutcome>();
      final repository = FakeAuthRepository(
        onResolve: (_) async => const NoStoredSession(),
        onVerifyClientCode: (_, _, _) => pending.future,
      );
      await render(tester, repository);
      await tester.enterText(
        find.byKey(const Key('verification-code')),
        '001234',
      );
      await tester.pumpWidget(const SizedBox());
      pending.complete(success);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  for (final kind in [CodeFailureKind.expired, CodeFailureKind.exhausted]) {
    testWidgets('$kind requires a new challenge', (tester) async {
      final repository = FakeAuthRepository(
        onResolve: (_) async => const NoStoredSession(),
        onVerifyClientCode: (_, _, _) async =>
            CodeVerificationFailure(kind, 'Request another code.'),
      );
      await render(tester, repository);
      await tester.enterText(
        find.byKey(const Key('verification-code')),
        '001234',
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('verification-code')),
        '001235',
      );
      await tester.pump();
      expect(repository.verifyClientCodeCalls, 1);
      expect(find.text('Request another code.'), findsOneWidget);
    });
  }

  testWidgets(
    'unconfirmed delivery retains resend recovery without a wrong-code state',
    (tester) async {
      final retrieval = FakeRetrieval();
      final repository = FakeAuthRepository(
        onResolve: (_) async => const NoStoredSession(),
      );
      final original = challenge();
      await render(
        tester,
        repository,
        retrieval: retrieval,
        initialChallenge: PhoneChallenge(
          id: original.id,
          maskedPhone: original.maskedPhone,
          expiresAt: original.expiresAt,
          resendAvailableAt: original.resendAvailableAt,
          deliveryStatus: PhoneCodeDeliveryStatus.failed,
        ),
      );
      retrieval.receive(initialId, '001234');
      await tester.pump();
      expect(repository.verifyClientCodeCalls, 0);
      expect(
        tester.widget<WeyonjeOtpField>(find.byType(WeyonjeOtpField)).invalid,
        isFalse,
      );
      expect(
        find.textContaining('SMS acceptance could not be confirmed'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('resend-phone-code')), findsOneWidget);
    },
  );

  testWidgets(
    'abandoned flow cannot overwrite a newer controller during route overlap',
    (tester) async {
      final oldResponse = Completer<AuthOutcome>();
      final repository = FakeAuthRepository(
        onResolve: (_) async => const NoStoredSession(),
        onVerifyClientCode: (id, _, _) =>
            id == initialId ? oldResponse.future : Future.value(success),
      );
      final container = await render(tester, repository);
      final old = container.read(
        phoneVerificationControllerProvider(initialId).notifier,
      );
      final oldRequest = old.verify(
        PhoneVerificationArguments(
          challenge: challenge(),
          purpose: PhoneVerificationPurpose.clientSignIn,
        ),
        '001234',
      );
      final subscription = container.listen(
        phoneVerificationControllerProvider(nextId),
        (_, _) {},
      );
      final next = container.read(
        phoneVerificationControllerProvider(nextId).notifier,
      );
      old.abandon();
      await next.verify(
        PhoneVerificationArguments(
          challenge: challenge(nextId),
          purpose: PhoneVerificationPurpose.clientSignIn,
        ),
        '001235',
      );
      oldResponse.complete(const InvalidSession('Obsolete response'));
      await oldRequest;
      expect(
        container.read(phoneVerificationControllerProvider(nextId)).phase,
        VerificationPhase.success,
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(
        container.read(launchControllerProvider),
        isA<LaunchAuthenticated>(),
      );
      subscription.close();
    },
  );

  for (final phase in [
    'entry',
    'checking',
    'invalid',
    'success',
    'large_text',
    'keyboard',
  ]) {
    testWidgets('verification visual $phase', (tester) async {
      final pending = Completer<AuthOutcome>();
      final repository = FakeAuthRepository(
        onResolve: (_) async => const NoStoredSession(),
        onVerifyClientCode: (_, _, _) => pending.future,
      );
      await render(
        tester,
        repository,
        scale: phase == 'large_text' ? 2 : 1,
        keyboard: phase == 'keyboard' ? 290 : 0,
      );
      if (phase == 'large_text') {
        await tester.enterText(
          find.byKey(const Key('verification-code')),
          '00123',
        );
        await tester.pump();
      }
      if (['checking', 'invalid', 'success', 'keyboard'].contains(phase)) {
        await tester.enterText(
          find.byKey(const Key('verification-code')),
          '001234',
        );
        await tester.pump();
        if (phase != 'checking') {
          pending.complete(
            phase == 'success'
                ? success
                : const CodeVerificationFailure(
                    CodeFailureKind.invalid,
                    'Check the six-digit code or request another code.',
                  ),
          );
          await tester.pump();
        }
      }
      if (phase == 'keyboard') {
        await tester.ensureVisible(find.byKey(const Key('resend-phone-code')));
        await tester.pumpAndSettle();
        expect(
          tester.getBottomRight(find.byKey(const Key('resend-phone-code'))).dy,
          lessThanOrEqualTo(470),
        );
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('visual/goldens/verification_$phase.png'),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      if (!pending.isCompleted) pending.complete(const CancelledSignIn());
      await tester.pump();
    });
  }
}
