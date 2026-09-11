class WorkflowException implements Exception {
  const WorkflowException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => message;
}

Map<String, dynamic> jsonObject(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  throw const FormatException('Expected a JSON object.');
}

List<Map<String, dynamic>> jsonList(Object? value) {
  if (value is! List) throw const FormatException('Expected a JSON list.');
  return value.map(jsonObject).toList(growable: false);
}

class WorkflowDashboard {
  const WorkflowDashboard({
    required this.pendingCount,
    required this.activeCount,
    required this.actionRequiredCount,
    required this.recentRequests,
    this.actorNumber,
  });

  factory WorkflowDashboard.fromJson(Object? value) {
    final map = jsonObject(value);
    return WorkflowDashboard(
      actorNumber: map['actorNumber'] as String?,
      pendingCount: map['pendingCount'] as int? ?? 0,
      activeCount: map['activeCount'] as int? ?? 0,
      actionRequiredCount: map['actionRequiredCount'] as int? ?? 0,
      recentRequests: jsonList(
        map['recentRequests'] ?? const <Object>[],
      ).map(ServiceRequestSummary.fromJson).toList(growable: false),
    );
  }

  final String? actorNumber;
  final int pendingCount;
  final int activeCount;
  final int actionRequiredCount;
  final List<ServiceRequestSummary> recentRequests;
}

class ServiceRequestSummary {
  const ServiceRequestSummary({
    required this.id,
    required this.reference,
    required this.origin,
    required this.status,
    required this.locationLabel,
    required this.scheduleMode,
    required this.updatedAt,
    this.requestedServiceAt,
    this.providerName,
    this.agreedPriceUgx,
    this.outstandingAction,
  });

  factory ServiceRequestSummary.fromJson(Object? value) {
    final map = jsonObject(value);
    return ServiceRequestSummary(
      id: map['id'] as String,
      reference: map['reference'] as String,
      origin: map['origin'] as String,
      status: map['status'] as String,
      locationLabel: map['locationLabel'] as String,
      scheduleMode: map['scheduleMode'] as String,
      updatedAt: DateTime.parse(map['updatedAt'] as String).toLocal(),
      requestedServiceAt: map['requestedServiceAt'] == null
          ? null
          : DateTime.parse(map['requestedServiceAt'] as String).toLocal(),
      providerName: map['providerName'] as String?,
      agreedPriceUgx: map['agreedPriceUgx'] as int?,
      outstandingAction: map['outstandingAction'] as String?,
    );
  }

  final String id;
  final String reference;
  final String origin;
  final String status;
  final String locationLabel;
  final String scheduleMode;
  final DateTime updatedAt;
  final DateTime? requestedServiceAt;
  final String? providerName;
  final int? agreedPriceUgx;
  final String? outstandingAction;
}

class ServiceRequestDetail extends ServiceRequestSummary {
  const ServiceRequestDetail({
    required super.id,
    required super.reference,
    required super.origin,
    required super.status,
    required super.locationLabel,
    required super.scheduleMode,
    required super.updatedAt,
    required this.clientName,
    required this.locationKind,
    required this.createdAt,
    super.requestedServiceAt,
    super.providerName,
    super.agreedPriceUgx,
    super.outstandingAction,
    this.clientPhone,
    this.clientEmail,
    this.additionalContactName,
    this.additionalContactPhone,
    this.providerUserId,
    this.latitude,
    this.longitude,
    this.toiletType,
    this.providerPhone,
    this.collectionOutcome,
    this.wasteCollected,
    this.followUpStatus,
    this.journeyToRequest,
    this.disposalJourney,
    this.disposalSite,
  });

  factory ServiceRequestDetail.fromJson(Object? value) {
    final map = jsonObject(value);
    final base = ServiceRequestSummary.fromJson(map);
    final location = map['location'] == null
        ? null
        : jsonObject(map['location']);
    return ServiceRequestDetail(
      id: base.id,
      reference: base.reference,
      origin: base.origin,
      status: base.status,
      locationLabel: base.locationLabel,
      scheduleMode: base.scheduleMode,
      updatedAt: base.updatedAt,
      requestedServiceAt: base.requestedServiceAt,
      providerName: base.providerName,
      agreedPriceUgx: base.agreedPriceUgx,
      outstandingAction: base.outstandingAction,
      clientName: map['clientName'] as String,
      clientPhone: map['clientPhone'] as String?,
      clientEmail: map['clientEmail'] as String?,
      additionalContactName: map['additionalContactName'] as String?,
      additionalContactPhone: map['additionalContactPhone'] as String?,
      providerUserId: map['providerUserId'] as String?,
      locationKind: map['locationKind'] as String,
      latitude: (location?['latitude'] as num?)?.toDouble(),
      longitude: (location?['longitude'] as num?)?.toDouble(),
      toiletType: map['toiletType'] as String?,
      providerPhone: map['providerPhone'] as String?,
      collectionOutcome: map['collectionOutcome'] as String?,
      wasteCollected: map['wasteCollected'] as bool?,
      followUpStatus: map['followUpStatus'] as String?,
      journeyToRequest: map['journeyToRequest'] == null
          ? null
          : JourneySnapshot.fromJson(map['journeyToRequest']),
      disposalJourney: map['disposalJourney'] == null
          ? null
          : JourneySnapshot.fromJson(map['disposalJourney']),
      disposalSite: map['disposalSite'] == null
          ? null
          : DisposalSite.fromJson(map['disposalSite']),
      createdAt: DateTime.parse(map['createdAt'] as String).toLocal(),
    );
  }

  final String clientName;
  final String? clientPhone;
  final String? clientEmail;
  final String? additionalContactName;
  final String? additionalContactPhone;
  final String? providerUserId;
  bool get canModify =>
      origin == 'MOBILE_APP' && status == 'PENDING' && providerUserId == null;
  final String locationKind;
  final double? latitude;
  final double? longitude;
  final String? toiletType;
  final String? providerPhone;
  final String? collectionOutcome;
  final bool? wasteCollected;
  final String? followUpStatus;
  final JourneySnapshot? journeyToRequest;
  final JourneySnapshot? disposalJourney;
  final DisposalSite? disposalSite;
  final DateTime createdAt;
}

class ProviderPendingRequest {
  const ProviderPendingRequest({
    required this.id,
    required this.reference,
    required this.origin,
    required this.locationLabel,
    required this.scheduleMode,
    required this.createdAt,
    this.toiletType,
    this.requestedServiceAt,
    this.assignmentStatus,
  });

  factory ProviderPendingRequest.fromJson(Object? value) {
    final map = jsonObject(value);
    return ProviderPendingRequest(
      id: map['id'] as String,
      reference: map['reference'] as String,
      origin: map['origin'] as String,
      locationLabel: map['locationLabel'] as String,
      scheduleMode: map['scheduleMode'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String).toLocal(),
      toiletType: map['toiletType'] as String?,
      assignmentStatus: map['assignmentStatus'] as String?,
      requestedServiceAt: map['requestedServiceAt'] == null
          ? null
          : DateTime.parse(map['requestedServiceAt'] as String).toLocal(),
    );
  }

  final String id;
  final String reference;
  final String origin;
  final String locationLabel;
  final String scheduleMode;
  final DateTime createdAt;
  final String? toiletType;
  final DateTime? requestedServiceAt;
  final String? assignmentStatus;
}

class JourneySnapshot {
  const JourneySnapshot({
    required this.id,
    required this.phase,
    required this.status,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.stale,
    required this.positionCount,
    this.latitude,
    this.longitude,
    this.accuracyMetres,
    this.latestPositionReceivedAt,
  });

  factory JourneySnapshot.fromJson(Object? value) {
    final map = jsonObject(value);
    final destination = jsonObject(map['destination']);
    final latest = map['latestPosition'] == null
        ? null
        : jsonObject(map['latestPosition']);
    return JourneySnapshot(
      id: map['id'] as String,
      phase: map['phase'] as String,
      status: map['status'] as String,
      destinationLatitude: (destination['latitude'] as num).toDouble(),
      destinationLongitude: (destination['longitude'] as num).toDouble(),
      stale: map['stale'] as bool,
      positionCount: map['positionCount'] as int,
      latitude: (latest?['latitude'] as num?)?.toDouble(),
      longitude: (latest?['longitude'] as num?)?.toDouble(),
      accuracyMetres: (latest?['accuracyMetres'] as num?)?.toDouble(),
      latestPositionReceivedAt: map['latestPositionReceivedAt'] == null
          ? null
          : DateTime.parse(map['latestPositionReceivedAt'] as String).toLocal(),
    );
  }

  final String id;
  final String phase;
  final String status;
  final double destinationLatitude;
  final double destinationLongitude;
  final bool stale;
  final int positionCount;
  final double? latitude;
  final double? longitude;
  final double? accuracyMetres;
  final DateTime? latestPositionReceivedAt;
}

class DisposalSite {
  const DisposalSite({
    required this.id,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    this.active = true,
  });
  factory DisposalSite.fromJson(Object? value) {
    final map = jsonObject(value);
    return DisposalSite(
      id: map['id'] as String,
      name: map['name'] as String,
      address: map['address'] as String,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      active: map['active'] as bool? ?? true,
    );
  }
  final String id;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final bool active;
}

class OperationalNotification {
  const OperationalNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.requestId,
    this.readAt,
  });
  factory OperationalNotification.fromJson(Object? value) {
    final map = jsonObject(value);
    return OperationalNotification(
      id: map['id'] as String,
      title: map['title'] as String,
      message: map['message'] as String,
      requestId: map['requestId'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String).toLocal(),
      readAt: map['readAt'] == null
          ? null
          : DateTime.parse(map['readAt'] as String).toLocal(),
    );
  }
  final String id;
  final String title;
  final String message;
  final String? requestId;
  final DateTime createdAt;
  final DateTime? readAt;
}

class LocationPolicy {
  const LocationPolicy({
    required this.sampleIntervalSeconds,
    required this.sampleDistanceMetres,
    required this.backgroundTrackingEnabled,
    required this.approvalNotice,
  });
  factory LocationPolicy.fromJson(Object? value) {
    final map = jsonObject(value);
    return LocationPolicy(
      sampleIntervalSeconds: map['sampleIntervalSeconds'] as int,
      sampleDistanceMetres: (map['sampleDistanceMetres'] as num).toDouble(),
      backgroundTrackingEnabled: map['backgroundTrackingEnabled'] as bool,
      approvalNotice: map['approvalNotice'] as String,
    );
  }
  final int sampleIntervalSeconds;
  final double sampleDistanceMetres;
  final bool backgroundTrackingEnabled;
  final String approvalNotice;
}

class ProviderAdministration {
  const ProviderAdministration({
    required this.userId,
    required this.companyName,
    required this.essLicenseNumber,
    required this.phoneNumber,
    required this.email,
    required this.workAddress,
    required this.status,
    required this.active,
    required this.history,
  });
  factory ProviderAdministration.fromJson(Object? value) {
    final map = jsonObject(value);
    return ProviderAdministration(
      userId: map['providerUserId'] as String,
      companyName: map['companyName'] as String,
      essLicenseNumber: map['essLicenseNumber'] as String,
      phoneNumber: map['phoneNumber'] as String,
      email: map['email'] as String,
      workAddress: map['workAddress'] as String,
      status: map['status'] as String,
      active: map['active'] as bool? ?? false,
      history: jsonList(map['statusHistory'] ?? const <Object>[]),
    );
  }
  final String userId;
  final String companyName;
  final String essLicenseNumber;
  final String phoneNumber;
  final String email;
  final String workAddress;
  final String status;
  final bool active;
  final List<Map<String, dynamic>> history;
}

class CallCentreClient {
  const CallCentreClient({
    required this.userId,
    required this.name,
    required this.phoneNumber,
    this.email,
  });
  factory CallCentreClient.fromJson(Object? value) {
    final map = jsonObject(value);
    return CallCentreClient(
      userId: map['userId'] as String,
      name: map['name'] as String,
      phoneNumber: map['phoneNumber'] as String,
      email: map['email'] as String?,
    );
  }
  final String userId;
  final String name;
  final String phoneNumber;
  final String? email;
}

class EligibleProvider {
  const EligibleProvider({required this.userId, required this.companyName});
  factory EligibleProvider.fromJson(Object? value) {
    final map = jsonObject(value);
    return EligibleProvider(
      userId: map['userId'] as String,
      companyName: map['companyName'] as String,
    );
  }
  final String userId;
  final String companyName;
}

class MapPlace {
  const MapPlace({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
  factory MapPlace.fromJson(Object? value) {
    final map = jsonObject(value);
    return MapPlace(
      name: map['name'] as String,
      address: map['address'] as String? ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
    );
  }
  final String name;
  final String address;
  final double latitude;
  final double longitude;
}

class MapRouteGuidance {
  const MapRouteGuidance({
    required this.distanceMetres,
    required this.duration,
    required this.encodedPolyline,
  });
  factory MapRouteGuidance.fromJson(Object? value) {
    final map = jsonObject(value);
    final polyline = jsonObject(map['polyline']);
    return MapRouteGuidance(
      distanceMetres: map['distanceMeters'] as int? ?? 0,
      duration: map['duration'] as String? ?? '',
      encodedPolyline: polyline['encodedPolyline'] as String? ?? '',
    );
  }
  final int distanceMetres;
  final String duration;
  final String encodedPolyline;
}
