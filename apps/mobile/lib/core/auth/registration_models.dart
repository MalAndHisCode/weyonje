enum ClientType { individual, organization }

enum ServiceProviderType { gulper, emptier }

enum PhoneCodeDeliveryStatus { sent, failed }

enum PhoneSignInActor { client, serviceProvider }

enum PhoneVerificationPurpose { registration, clientSignIn, providerSignIn }

class PhoneChallenge {
  const PhoneChallenge({
    required this.id,
    required this.maskedPhone,
    required this.expiresAt,
    required this.resendAvailableAt,
    required this.deliveryStatus,
  });

  final String id;
  final String maskedPhone;
  final DateTime expiresAt;
  final DateTime resendAvailableAt;
  final PhoneCodeDeliveryStatus deliveryStatus;

  factory PhoneChallenge.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid phone challenge.');
    }
    final id = value['challengeId'];
    final maskedPhone = value['maskedPhone'];
    final expiresAt = DateTime.tryParse(value['expiresAt'] as String? ?? '');
    final resendAt = DateTime.tryParse(
      value['resendAvailableAt'] as String? ?? '',
    );
    final delivery = value['deliveryStatus'];
    if (id is! String ||
        maskedPhone is! String ||
        expiresAt == null ||
        resendAt == null ||
        (delivery != 'SENT' && delivery != 'FAILED')) {
      throw const FormatException('Invalid phone challenge.');
    }
    return PhoneChallenge(
      id: id,
      maskedPhone: maskedPhone,
      expiresAt: expiresAt.toUtc(),
      resendAvailableAt: resendAt.toUtc(),
      deliveryStatus: delivery == 'SENT'
          ? PhoneCodeDeliveryStatus.sent
          : PhoneCodeDeliveryStatus.failed,
    );
  }
}

class PhoneVerificationArguments {
  const PhoneVerificationArguments({
    required this.challenge,
    required this.purpose,
  });

  final PhoneChallenge challenge;
  final PhoneVerificationPurpose purpose;
}

class ClientRegistrationArguments {
  const ClientRegistrationArguments(this.phoneNumber);
  final String phoneNumber;
}

class ClientRegistrationRequest {
  const ClientRegistrationRequest({
    required this.clientType,
    required this.phoneNumber,
    this.firstName,
    this.lastName,
    this.organizationName,
    this.email,
    this.contactPersonName,
    this.contactPersonPhone,
  });

  final ClientType clientType;
  final String phoneNumber;
  final String? firstName;
  final String? lastName;
  final String? organizationName;
  final String? email;
  final String? contactPersonName;
  final String? contactPersonPhone;

  Map<String, Object> toJson() => {
    'clientType': clientType == ClientType.individual
        ? 'INDIVIDUAL'
        : 'ORGANIZATION',
    'phoneNumber': phoneNumber,
    'firstName': ?firstName,
    'lastName': ?lastName,
    'organizationName': ?organizationName,
    'email': ?email,
    'contactPersonName': ?contactPersonName,
    'contactPersonPhone': ?contactPersonPhone,
  };
}

class ServiceProviderRegistrationRequest {
  const ServiceProviderRegistrationRequest({
    required this.essLicenseNumber,
    required this.companyName,
    required this.phoneNumber,
    required this.email,
    required this.workAddress,
    required this.providerType,
    required this.contactPersonName,
    required this.contactPersonPhone,
  });

  final String essLicenseNumber;
  final String companyName;
  final String phoneNumber;
  final String email;
  final String workAddress;
  final ServiceProviderType providerType;
  final String contactPersonName;
  final String contactPersonPhone;

  Map<String, Object> toJson() => {
    'essLicenseNumber': essLicenseNumber,
    'companyName': companyName,
    'phoneNumber': phoneNumber,
    'email': email,
    'workAddress': workAddress,
    'providerType': providerType == ServiceProviderType.gulper
        ? 'GULPER'
        : 'EMPTIER',
    'contactPersonName': contactPersonName,
    'contactPersonPhone': contactPersonPhone,
  };
}

sealed class ChallengeOutcome {
  const ChallengeOutcome();
}

class ChallengeCreated extends ChallengeOutcome {
  const ChallengeCreated(this.challenge);
  final PhoneChallenge challenge;
}

class RegistrationRequired extends ChallengeOutcome {
  const RegistrationRequired();
}

enum RequestLimitCategory { hourly, cooldown, clientRequest, providerRequest }

class ChallengeFailure extends ChallengeOutcome {
  const ChallengeFailure(
    this.message, {
    this.rateLimited = false,
    this.retryAt,
    this.limitCategory,
  });
  final DateTime? retryAt;
  final RequestLimitCategory? limitCategory;
  final String message;
  final bool rateLimited;
}
