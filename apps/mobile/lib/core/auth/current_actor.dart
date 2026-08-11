enum ActorType {
  client,
  serviceProvider,
  kccaStaff;

  static ActorType parse(Object? value) => switch (value) {
    'CLIENT' => client,
    'SERVICE_PROVIDER' => serviceProvider,
    'KCCA_STAFF' => kccaStaff,
    _ => throw const FormatException('Unrecognized actor type.'),
  };
}

enum ActorAccess {
  eligible,
  restricted,
  denied;

  static ActorAccess parse(Object? value) => switch (value) {
    'ELIGIBLE' => eligible,
    'RESTRICTED' => restricted,
    'DENIED' => denied,
    _ => throw const FormatException('Unrecognized actor access.'),
  };
}

enum ProviderStatus {
  pending,
  approved,
  rejected,
  inactive,
  disabled;

  static ProviderStatus? parse(Object? value) => switch (value) {
    null => null,
    'PENDING' => pending,
    'APPROVED' => approved,
    'REJECTED' => rejected,
    'INACTIVE' => inactive,
    'DISABLED' => disabled,
    _ => throw const FormatException('Unrecognized provider status.'),
  };
}

class CurrentActor {
  const CurrentActor({
    required this.actorType,
    required this.access,
    this.providerStatus,
  });

  factory CurrentActor.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid current actor response.');
    }
    final actorType = ActorType.parse(value['actorType']);
    final providerStatus = ProviderStatus.parse(value['providerStatus']);
    if (actorType == ActorType.serviceProvider && providerStatus == null) {
      throw const FormatException('Service provider eligibility is missing.');
    }
    if (actorType != ActorType.serviceProvider && providerStatus != null) {
      throw const FormatException('Unexpected provider eligibility data.');
    }
    return CurrentActor(
      actorType: actorType,
      access: ActorAccess.parse(value['access']),
      providerStatus: providerStatus,
    );
  }

  final ActorType actorType;
  final ActorAccess access;
  final ProviderStatus? providerStatus;
}
