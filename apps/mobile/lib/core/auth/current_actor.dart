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
    this.emailVerified = false,
    this.providerStatus,
    this.providerNumber,
    this.providerRejectionReason,
    this.mobileMonitoringPermitted = false,
    this.providerApprovalPermitted = false,
    this.callCentreOperationsPermitted = false,
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
      emailVerified: value['emailVerified'] as bool? ?? false,
      providerStatus: providerStatus,
      providerNumber: value['providerNumber'] as String?,
      providerRejectionReason: value['providerRejectionReason'] as String?,
      mobileMonitoringPermitted:
          value['mobileMonitoringPermitted'] as bool? ?? false,
      providerApprovalPermitted:
          value['providerApprovalPermitted'] as bool? ?? false,
      callCentreOperationsPermitted:
          value['callCentreOperationsPermitted'] as bool? ?? false,
    );
  }

  final ActorType actorType;
  final ActorAccess access;
  final bool emailVerified;
  final ProviderStatus? providerStatus;
  final String? providerNumber;
  final String? providerRejectionReason;
  final bool mobileMonitoringPermitted;
  final bool providerApprovalPermitted;
  final bool callCentreOperationsPermitted;
}
