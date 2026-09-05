import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/features/authentication/data/auth_repository.dart';
import 'package:frontend/features/authentication/domain/user_profile.dart';
import 'package:frontend/features/authentication/domain/user_role.dart';
import 'package:frontend/features/kyc/data/kyc_repository.dart';
import 'package:frontend/features/kyc/domain/kyc_models.dart';
import 'package:frontend/features/kyc/presentation/admin_kyc_screen.dart';

/// A test-only MockKycRepository that returns controlled data synchronously
/// and allows inspection of review calls.
class _TestAdminKycRepository extends MockKycRepository {
  final List<String> reviewedIds = [];
  final List<String> reviewStatuses = [];

  @override
  Future<KycRecord> submitKyc(KycRecord submission) async {
    final record = KycRecord(
      id: submission.id.isNotEmpty ? submission.id : 'KYC-${records.length + 1}',
      userId: submission.userId,
      userRole: submission.userRole,
      fullName: submission.fullName,
      dateOfBirth: submission.dateOfBirth,
      address: submission.address,
      district: submission.district,
      state: submission.state,
      pinCode: submission.pinCode,
      idType: submission.idType,
      idNumber: submission.idNumber,
      phone: submission.phone,
      status: KycStatus.pending,
      submittedAt: DateTime(2026, 7, 18, 12),
      renewableEnergySource: submission.renewableEnergySource,
      installedCapacityKw: submission.installedCapacityKw,
      plantLocation: submission.plantLocation,
      utilityLicenseNumber: submission.utilityLicenseNumber,
      bankAccountNumber: submission.bankAccountNumber,
      bankIfscCode: submission.bankIfscCode,
      bankAccountHolder: submission.bankAccountHolder,
    );
    records[record.id] = record;
    return record;
  }

  @override
  Future<KycAdminSummary> getAdminSummary() async {
    final allRecords = records.values.toList();
    return KycAdminSummary(
      totalApplications: allRecords.length,
      pending: allRecords.where((r) => r.status == KycStatus.pending).length,
      verified: allRecords.where((r) => r.status == KycStatus.verified).length,
      rejected: allRecords.where((r) => r.status == KycStatus.rejected).length,
      resubmissionRequested: allRecords.where((r) => r.status == KycStatus.resubmissionRequested).length,
    );
  }

  @override
  Future<PaginatedKycRecords> listAll({String? status, String? search, int page = 1, int pageSize = 20}) async {
    var items = records.values.toList();
    if (status != null) items = items.where((r) => r.status.value == status).toList();
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      items = items.where((r) => r.fullName.toLowerCase().contains(q) || r.idNumber.toLowerCase().contains(q)).toList();
    }
    items.sort((a, b) => (b.submittedAt ?? DateTime(2000)).compareTo(a.submittedAt ?? DateTime(2000)));
    return PaginatedKycRecords(
      items: items,
      page: 1,
      pageSize: items.length,
      total: items.length,
      totalPages: 1,
    );
  }

  @override
  Future<KycRecord> reviewKyc(String kycId, String status, String? remarks) async {
    reviewedIds.add(kycId);
    reviewStatuses.add(status);
    final existing = records[kycId];
    if (existing == null) throw Exception('Not found');
    final updated = KycRecord(
      id: existing.id,
      userId: existing.userId,
      userRole: existing.userRole,
      fullName: existing.fullName,
      dateOfBirth: existing.dateOfBirth,
      address: existing.address,
      district: existing.district,
      state: existing.state,
      pinCode: existing.pinCode,
      idType: existing.idType,
      idNumber: existing.idNumber,
      phone: existing.phone,
      status: KycStatus.fromValue(status),
      reviewedBy: 'admin',
      reviewedAt: DateTime.now(),
      remarks: remarks,
      submittedAt: existing.submittedAt,
      renewableEnergySource: existing.renewableEnergySource,
      installedCapacityKw: existing.installedCapacityKw,
      plantLocation: existing.plantLocation,
      utilityLicenseNumber: existing.utilityLicenseNumber,
    );
    records[kycId] = updated;
    return updated;
  }
}

/// Seeds the test repository with sample KYC records of different statuses.
KycRecord _seedRecord(_TestAdminKycRepository repo, String id, String name, String role, KycStatus status) {
  final record = KycRecord(
    id: id,
    userId: 'user-$id',
    userRole: role,
    fullName: name,
    dateOfBirth: '1990-01-01',
    address: '123 Test St',
    district: 'Ernakulam',
    state: 'Kerala',
    pinCode: '682001',
    idType: 'aadhar',
    idNumber: '1234-5678-9012',
    phone: '9876543210',
    status: status,
    submittedAt: DateTime(2026, 7, 18, 12),
    renewableEnergySource: role == 'producer' ? 'Solar' : null,
    installedCapacityKw: role == 'producer' ? 5.0 : null,
    remarks: status == KycStatus.rejected ? 'Documents not clear' : null,
  );
  repo.records[id] = record;
  return record;
}

/// Build the admin KYC screen with proper provider overrides for testing.
Widget _adminKycScreen({_TestAdminKycRepository? repo}) {
  final effectiveRepo = repo ?? testRepo;

  return MaterialApp(
    theme: buildVoltShareTheme(),
    home: ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            supabaseUrl: '',
            supabasePublishableKey: '',
            useMockBackend: true,
          ),
        ),
        currentProfileProvider.overrideWith((ref) async => adminProfile),
        kycRepositoryProvider.overrideWithValue(effectiveRepo),
      ],
      child: const AdminKycScreen(),
    ),
  );
}

_TestAdminKycRepository testRepo = _TestAdminKycRepository();
UserProfile adminProfile = UserProfile(
  id: 'admin-1',
  email: 'admin@voltshare.com',
  fullName: 'Admin Volt',
  phone: '9999999999',
  role: UserRole.admin,
  city: 'Kochi',
  district: 'Ernakulam',
  state: 'Kerala',
);

void main() {
  setUp(() {
    testRepo = _TestAdminKycRepository();
    _seedRecord(testRepo, 'pending-1', 'Alice Kumar', 'consumer', KycStatus.pending);
    _seedRecord(testRepo, 'pending-2', 'Bob Mathew', 'producer', KycStatus.pending);
    _seedRecord(testRepo, 'verified-1', 'Carol Dcruz', 'consumer', KycStatus.verified);
    _seedRecord(testRepo, 'rejected-1', 'David Raj', 'consumer', KycStatus.rejected);
    _seedRecord(testRepo, 'resubmit-1', 'Eva Thomas', 'producer', KycStatus.resubmissionRequested);

    adminProfile = UserProfile(
      id: 'admin-1',
      email: 'admin@voltshare.com',
      fullName: 'Admin Volt',
      phone: '9999999999',
      role: UserRole.admin,
      city: 'Kochi',
      district: 'Ernakulam',
      state: 'Kerala',
    );
  });

  group('Admin KYC Screen', () {
    /// Helper to pump the widget tree and settle async providers.
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(_adminKycScreen());
      // FutureProvider needs multiple pump cycles to resolve:
      // pump 1: build widget, create providers, start futures
      // pump 2: resolve microtasks, providers get data
      // pump 3: rebuild with data
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    testWidgets('renders summary cards with correct counts', (tester) async {
      await pumpScreen(tester);

      // Summary cards — counts:
      // Total=5, Pending=2, Verified=1, Rejected=1, Resubmit=1
      expect(find.text('Total'), findsOneWidget);
      // "5" appears once (Total card value)
      expect(find.text('5'), findsOneWidget);
      // "Pending" appears in summary card label AND filter chip
      expect(find.text('Pending'), findsWidgets);
      // "2" only as Pending card value
      expect(find.text('2'), findsOneWidget);
      // "Verified" in summary + filter
      expect(find.text('Verified'), findsWidgets);
      // "1" appears in 3 summary cards: Verified, Rejected, Resubmit
      expect(find.text('1'), findsAtLeast(2));
      // "Rejected" in summary + filter
      expect(find.text('Rejected'), findsWidgets);
      // "Resubmit" only in summary (no filter chip for resubmission)
      expect(find.text('Resubmit'), findsOneWidget);
    });

    testWidgets('renders filter chips', (tester) async {
      await pumpScreen(tester);

      expect(find.text('All'), findsOneWidget);
      // Filter chips: All, Pending, Verified, Rejected
      // Summary cards ALSO show Pending, Verified, Rejected
      expect(find.text('Pending'), findsWidgets);
      expect(find.text('Verified'), findsWidgets);
      expect(find.text('Rejected'), findsWidgets);
    });

    testWidgets('shows KYC cards with initials and status badge', (tester) async {
      await pumpScreen(tester);

      // Check all names appear
      expect(find.text('Alice Kumar'), findsOneWidget);
      expect(find.text('Bob Mathew'), findsOneWidget);
      expect(find.text('Carol Dcruz'), findsOneWidget);
      expect(find.text('David Raj'), findsOneWidget);
      expect(find.text('Eva Thomas'), findsOneWidget);

      // Check status labels
      expect(find.text('Pending'), findsWidgets); // Multiple instances: badges + summary + filter
      expect(find.text('Verified'), findsWidgets); // badge + summary + filter
      expect(find.text('Rejected'), findsWidgets); // badge + summary + filter
      expect(find.text('Resubmission Requested'), findsOneWidget);

      // Check role + location text
      expect(find.textContaining('consumer • Ernakulam, Kerala'), findsWidgets);
      expect(find.textContaining('producer • Ernakulam, Kerala'), findsWidgets);
    });

    testWidgets('shows empty state when no records', (tester) async {
      final emptyRepo = _TestAdminKycRepository();
      await tester.pumpWidget(MaterialApp(
        theme: buildVoltShareTheme(),
        home: ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(supabaseUrl: '', supabasePublishableKey: '', useMockBackend: true),
            ),
            currentProfileProvider.overrideWith((ref) async => adminProfile),
            kycRepositoryProvider.overrideWithValue(emptyRepo),
          ],
          child: const AdminKycScreen(),
        ),
      ));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('No KYC applications found'), findsOneWidget);
    });

    testWidgets('filtering by status shows only matching records', (tester) async {
      await pumpScreen(tester);

      // Tap Pending filter chip (find the ActionChip with text 'Pending')
      final pendingChips = find.widgetWithText(ActionChip, 'Pending');
      expect(pendingChips, findsOneWidget);
      await tester.tap(pendingChips);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Should show only pending records
      expect(find.text('Alice Kumar'), findsOneWidget);
      expect(find.text('Bob Mathew'), findsOneWidget);
      // Non-pending should be hidden
      expect(find.text('Carol Dcruz'), findsNothing);
      expect(find.text('David Raj'), findsNothing);
      expect(find.text('Eva Thomas'), findsNothing);
    });

    testWidgets('filtering by Verified shows only verified records', (tester) async {
      await pumpScreen(tester);

      // Tap the Verified chip specifically
      final verifiedChip = find.widgetWithText(ActionChip, 'Verified');
      expect(verifiedChip, findsOneWidget);
      await tester.tap(verifiedChip);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('Carol Dcruz'), findsOneWidget);
      expect(find.text('Alice Kumar'), findsNothing);
    });

    testWidgets('tapping All filter resets and shows all records', (tester) async {
      await pumpScreen(tester);

      // First filter to Pending
      await tester.tap(find.widgetWithText(ActionChip, 'Pending'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.text('Alice Kumar'), findsOneWidget);
      expect(find.text('Carol Dcruz'), findsNothing);

      // Then tap All
      await tester.tap(find.text('All'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // All records should be visible again
      expect(find.text('Alice Kumar'), findsOneWidget);
      expect(find.text('Bob Mathew'), findsOneWidget);
      expect(find.text('Carol Dcruz'), findsOneWidget);
      expect(find.text('David Raj'), findsOneWidget);
      expect(find.text('Eva Thomas'), findsOneWidget);
    });

    testWidgets('tapping a pending KYC card opens detail bottom sheet', (tester) async {
      await pumpScreen(tester);

      // Tap the first KYC card (Alice Kumar - pending)
      await tester.tap(find.text('Alice Kumar'));
      await tester.pump();
      await tester.pump();

      // Detail sheet should show
      expect(find.text('KYC Application'), findsOneWidget);
      expect(find.text('consumer'), findsOneWidget);
      // "Approve" appears only in the detail sheet (bottom sheet buttons)
      // "Resubmit" appears in summary card AND detail sheet button
      expect(find.text('Approve'), findsAtLeast(1));
      expect(find.text('Reject'), findsAtLeast(1));
      expect(find.text('Resubmit'), findsAtLeast(1));
    });

    testWidgets('detail sheet shows producer-specific fields', (tester) async {
      await pumpScreen(tester);

      // Tap Bob Mathew (producer)
      await tester.tap(find.text('Bob Mathew'));
      await tester.pump();
      await tester.pump();

      expect(find.text('KYC Application'), findsOneWidget);
      // Producer fields
      expect(find.text('Energy Source'), findsOneWidget);
      expect(find.text('Solar'), findsOneWidget);
      expect(find.text('Capacity'), findsOneWidget);
      expect(find.text('5.0 kW'), findsOneWidget);
    });

    testWidgets('detail sheet for verified record hides review buttons', (tester) async {
      await pumpScreen(tester);

      // Tap Carol Dcruz (verified)
      await tester.tap(find.text('Carol Dcruz'));
      await tester.pump();
      await tester.pump();

      expect(find.text('KYC Application'), findsOneWidget);
      // Review buttons should be hidden for verified records in the sheet
      // "Approve" and "Reject" should NOT appear anywhere in the sheet
      // "Resubmit" still appears in summary card (outside sheet)
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    });

    testWidgets('detail sheet for rejected record shows admin remarks', (tester) async {
      await pumpScreen(tester);

      // Tap David Raj (rejected)
      await tester.tap(find.text('David Raj'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Admin Notes'), findsOneWidget);
      expect(find.text('Documents not clear'), findsOneWidget);
    });

    testWidgets('approving a KYC reduces pending count', (tester) async {
      await pumpScreen(tester);

      // Initially: Total=5, Pending=2
      expect(find.text('5'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Open Alice Kumar's detail
      await tester.tap(find.text('Alice Kumar'));
      await tester.pumpAndSettle();

      // Scroll bottom sheet to make Approve button visible, then tap
      await tester.ensureVisible(find.text('Approve').last);
      await tester.pump();
      await tester.tap(find.text('Approve').last);
      await tester.pump();
      await tester.pump();

      // Confirm dialog now shows on top
      expect(find.text('Are you sure you want to approve this KYC application?'), findsOneWidget);

      // Tap Approve in the dialog
      await tester.tap(find.text('Approve').last);
      await tester.pump();
      await tester.pump();

      // Verify review was called
      expect(testRepo.reviewedIds, contains('pending-1'));
      expect(testRepo.reviewStatuses, contains('verified'));
    });

    testWidgets('rejecting a KYC shows dialog with remarks field', (tester) async {
      await pumpScreen(tester);

      // Open Alice Kumar's detail
      await tester.tap(find.text('Alice Kumar'));
      await tester.pumpAndSettle();

      // Scroll bottom sheet to make Reject button visible, then tap
      await tester.ensureVisible(find.text('Reject'));
      await tester.pump();
      await tester.tap(find.text('Reject'));
      await tester.pump();
      await tester.pump();

      // Dialog should show with Reject KYC title
      expect(find.text('Reject KYC'), findsOneWidget);
      // Should have a text field for reason
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('search icon opens search dialog', (tester) async {
      await pumpScreen(tester);

      // Find and tap search icon button
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.pump();

      // Search dialog should appear
      expect(find.text('Search KYC'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
    });
  });

  group('Admin KYC Repository', () {
    test('getAdminSummary returns correct stats after review', () async {
      final repo = MockKycRepository();
      await repo.submitKyc(KycRecord(
        id: '', userId: 'u1', userRole: 'consumer',
        fullName: 'Test', dateOfBirth: '1990-01-01', address: 'Addr',
        district: 'Dist', state: 'State', pinCode: '123456',
        idType: 'aadhar', idNumber: '1234', phone: '9876543210',
        status: KycStatus.notSubmitted,
      ));

      var summary = await repo.getAdminSummary();
      expect(summary.totalApplications, 1);
      expect(summary.pending, 1);
      expect(summary.verified, 0);

      final record = await repo.getMyKyc();
      await repo.reviewKyc(record!.id, 'verified', null);

      summary = await repo.getAdminSummary();
      expect(summary.verified, 1);
      expect(summary.pending, 0);
    });

    test('listAll filters by status correctly', () async {
      final repo = MockKycRepository();
      for (var i = 0; i < 3; i++) {
        await repo.submitKyc(KycRecord(
          id: '', userId: 'u$i', userRole: 'consumer',
          fullName: 'User $i', dateOfBirth: '1990-01-01', address: 'Addr',
          district: 'Dist', state: 'State', pinCode: '123456',
          idType: 'aadhar', idNumber: 'id$i', phone: '9876543210',
          status: KycStatus.notSubmitted,
        ));
      }

      // Get first record and verify it
      final all = await repo.listAll();
      final pending = await repo.listAll(status: 'pending');
      expect(all.total, 3);
      expect(pending.total, 3);

      // Verify one and check filter
      final record = await repo.getMyKyc();
      await repo.reviewKyc(record!.id, 'verified', null);

      final pendingAfter = await repo.listAll(status: 'pending');
      final verifiedAfter = await repo.listAll(status: 'verified');
      expect(pendingAfter.total, 2);
      expect(verifiedAfter.total, 1);
    });

    test('listAll searches by name', () async {
      final repo = MockKycRepository();
      await repo.submitKyc(KycRecord(
        id: '', userId: 'u1', userRole: 'consumer',
        fullName: 'Ravi Sharma', dateOfBirth: '1990-01-01', address: 'Addr',
        district: 'Dist', state: 'State', pinCode: '123456',
        idType: 'aadhar', idNumber: '1234', phone: '9876543210',
        status: KycStatus.notSubmitted,
      ));
      await repo.submitKyc(KycRecord(
        id: '', userId: 'u2', userRole: 'producer',
        fullName: 'Priya Patel', dateOfBirth: '1990-01-01', address: 'Addr',
        district: 'Dist', state: 'State', pinCode: '123456',
        idType: 'pan', idNumber: 'ABCDE1234F', phone: '9876543211',
        status: KycStatus.notSubmitted,
      ));

      final searchRavi = await repo.listAll(search: 'Ravi');
      expect(searchRavi.total, 1);
      expect(searchRavi.items.first.fullName, 'Ravi Sharma');

      final searchPriya = await repo.listAll(search: 'Priya');
      expect(searchPriya.total, 1);
      expect(searchPriya.items.first.fullName, 'Priya Patel');

      final searchAll = await repo.listAll();
      expect(searchAll.total, 2);
    });
  });
}
