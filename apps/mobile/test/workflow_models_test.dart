import 'package:flutter_test/flutter_test.dart';
import 'package:weyonje/features/workflows/domain/workflow_models.dart';

void main() {
  test('parses a dashboard with current workflow summaries', () {
    final dashboard = WorkflowDashboard.fromJson({
      'actorNumber': 'WSP-123',
      'pendingCount': 2,
      'activeCount': 1,
      'actionRequiredCount': 1,
      'recentRequests': [
        {
          'id': 'request-1',
          'reference': 'WRQ-1',
          'origin': 'MOBILE_APP',
          'status': 'PENDING',
          'locationLabel': 'Nakawa',
          'scheduleMode': 'ASAP',
          'updatedAt': '2026-08-19T10:00:00.000Z',
        },
      ],
    });

    expect(dashboard.actorNumber, 'WSP-123');
    expect(dashboard.pendingCount, 2);
    expect(dashboard.recentRequests.single.scheduleMode, 'ASAP');
  });

  test(
    'keeps negative follow-up and collected-waste disposal state separate',
    () {
      final detail = ServiceRequestDetail.fromJson({
        'id': 'request-1',
        'reference': 'WRQ-1',
        'origin': 'MOBILE_APP',
        'status': 'COLLECTION_COMPLETED',
        'locationLabel': 'Nakawa',
        'scheduleMode': 'SCHEDULED',
        'requestedServiceAt': '2026-08-20T10:00:00.000Z',
        'updatedAt': '2026-08-19T10:00:00.000Z',
        'clientName': 'Amina',
        'locationKind': 'TEXT',
        'collectionOutcome': 'LEFT_INCOMPLETE',
        'wasteCollected': true,
        'followUpStatus': 'OPEN',
        'disposalSite': {
          'id': 'site-1',
          'name': 'Approved site',
          'address': 'Kampala',
        },
        'createdAt': '2026-08-19T09:00:00.000Z',
      });

      expect(detail.wasteCollected, isTrue);
      expect(detail.followUpStatus, 'OPEN');
      expect(detail.disposalSite?.name, 'Approved site');
      expect(detail.status, 'COLLECTION_COMPLETED');
    },
  );

  test('parses provisional policy values returned by the API', () {
    final policy = LocationPolicy.fromJson({
      'sampleIntervalSeconds': 15,
      'sampleDistanceMetres': 25,
      'backgroundTrackingEnabled': true,
      'approvalNotice': 'Requires KCCA approval.',
    });

    expect(policy.sampleIntervalSeconds, 15);
    expect(policy.sampleDistanceMetres, 25);
    expect(policy.approvalNotice, contains('KCCA'));
  });
}
