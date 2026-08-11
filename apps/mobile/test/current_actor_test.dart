import 'package:flutter_test/flutter_test.dart';
import 'package:weyonje/core/auth/current_actor.dart';

void main() {
  test('parses the minimum current-actor contract', () {
    expect(
      CurrentActor.fromJson({
        'actorType': 'SERVICE_PROVIDER',
        'access': 'RESTRICTED',
        'providerStatus': 'PENDING',
      }).providerStatus,
      ProviderStatus.pending,
    );
  });

  test('denies unrecognized and internally inconsistent contract values', () {
    expect(
      () =>
          CurrentActor.fromJson({'actorType': 'UNKNOWN', 'access': 'ELIGIBLE'}),
      throwsFormatException,
    );
    expect(
      () => CurrentActor.fromJson({
        'actorType': 'SERVICE_PROVIDER',
        'access': 'ELIGIBLE',
      }),
      throwsFormatException,
    );
  });
}
