import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/error_message.dart';
import '../../../core/widgets/voltshare_ui.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/user_profile.dart';
import '../../kyc/providers/kyc_provider.dart';
import '../../kyc/domain/kyc_models.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _error;
  bool _isSigningOut = false;

  Future<void> _logout() async {
    setState(() {
      _isSigningOut = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signOut();
    } on AppException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final kycAsync = ref.watch(myKycProvider);
    final needsKycAsync = ref.watch(needsKycProvider);

    return Scaffold(
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPageHeader(title: 'Profile', showBackButton: false),
            const SizedBox(height: 16),
            profile.when(
              data: (value) {
                if (value == null)
                  return const ErrorMessage(message: 'No profile found.');
                return _ProfileDetails(
                  profile: value,
                  kyc: kycAsync.valueOrNull,
                  needsKyc: needsKycAsync.valueOrNull ?? true,
                  error: _error,
                  isSigningOut: _isSigningOut,
                  onLogout: _logout,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  ErrorMessage(message: 'Profile unavailable: $error'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileDetails extends StatelessWidget {
  final UserProfile profile;
  final KycRecord? kyc;
  final bool needsKyc;
  final String? error;
  final bool isSigningOut;
  final VoidCallback onLogout;

  const _ProfileDetails({
    required this.profile,
    required this.kyc,
    required this.needsKyc,
    this.error,
    required this.isSigningOut,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile header
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    color: theme.colorScheme.primary,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.fullName.isEmpty
                            ? 'VoltShare user'
                            : profile.fullName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.badge_outlined, size: 18),
                            label: Text(profile.role.value),
                          ),
                          Chip(
                            avatar: Icon(
                              profile.isActive
                                  ? Icons.check_circle_outline
                                  : Icons.lock_outline,
                              size: 18,
                            ),
                            label: Text(
                              profile.isActive ? 'Active' : 'Inactive',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // KYC Section
        if (kyc == null || kyc!.status == KycStatus.notSubmitted || kyc!.status == KycStatus.rejected || kyc!.status == KycStatus.resubmissionRequested || needsKyc)
          _ActionCard(
            icon: Icons.verified_user_outlined,
            title: 'KYC Verification Required',
            subtitle: 'Complete eKYC to access marketplace & trading features',
            trailing: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
            ),
            onTap: () => context.push('/kyc/form'),
          )
        else
          _ActionCard(
            icon: Icons.verified_outlined,
            title: 'KYC: ${kyc!.status.label}',
            subtitle: kyc!.status == KycStatus.verified
                ? 'Identity verified'
                : (kyc!.remarks?.isNotEmpty == true ? kyc!.remarks! : 'Under review'),
            trailing: Icon(
              kyc!.status == KycStatus.verified
                  ? Icons.check_circle
                  : Icons.hourglass_empty,
              color: kyc!.status == KycStatus.verified
                  ? Colors.green
                  : Colors.orange,
            ),
            onTap: () => context.push('/kyc'),
          ),

        const SizedBox(height: 8),

        // Profile info
        ProfileInfoTile(
          label: 'Email',
          value: profile.email,
          icon: Icons.email_outlined,
        ),
        const SizedBox(height: 8),
        ProfileInfoTile(
          label: 'Role',
          value: profile.role.value,
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: 8),
        ProfileInfoTile(
          label: 'Status',
          value: profile.isActive ? 'Active' : 'Inactive',
          icon: Icons.verified_user_outlined,
        ),
        const SizedBox(height: 8),
        ProfileInfoTile(
          label: 'Phone',
          value: profile.phone,
          icon: Icons.phone_outlined,
        ),
        const SizedBox(height: 8),
        ProfileInfoTile(
          label: 'City',
          value: profile.city,
          icon: Icons.location_city_outlined,
        ),
        const SizedBox(height: 8),
        ProfileInfoTile(
          label: 'District',
          value: profile.district,
          icon: Icons.map_outlined,
        ),
        const SizedBox(height: 8),
        ProfileInfoTile(
          label: 'State',
          value: profile.state,
          icon: Icons.public_outlined,
        ),
        if (error != null) ...[
          const SizedBox(height: 14),
          ErrorMessage(message: error!),
        ],

        const SizedBox(height: 20),
        const Divider(),

        // === IDENTITY & KYC ===
        const SizedBox(height: 8),
        Text(
          'Identity & Verification',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        _ActionCard(
          icon: Icons.badge_outlined,
          title: 'eKYC Document Verification',
          subtitle: kyc != null
              ? 'Status: ${kyc!.status.label}'
              : 'Submit government ID & solar ownership proof',
          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          onTap: () => context.push(kyc == null ? '/kyc/form' : '/kyc'),
        ),

        const SizedBox(height: 16),
        const Divider(),

        // === SMART METER & HARDWARE ===
        const SizedBox(height: 8),
        Text(
          'Smart Meter & Devices',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        _ActionCard(
          icon: Icons.electric_meter_outlined,
          title: 'Live Smart Meter',
          subtitle: 'Real-time IoT meter monitoring via PubNub',
          onTap: () => context.push(AppRoutes.smartMeter),
        ),

        const SizedBox(height: 16),
        const Divider(),

        // === HELP & SUPPORT SECTION ===
        const SizedBox(height: 8),
        Text(
          'Help & Support',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),

        _ActionCard(
          icon: Icons.question_answer_outlined,
          title: 'Frequently Asked Questions',
          subtitle: 'Find answers to common questions',
          onTap: () => _showFAQ(context),
        ),
        _ActionCard(
          icon: Icons.headset_mic_outlined,
          title: 'Contact Support',
          subtitle: 'Get help from our support team',
          onTap: () => context.push(AppRoutes.supportTickets),
        ),
        _ActionCard(
          icon: Icons.phone_in_talk_outlined,
          title: 'Emergency Numbers',
          subtitle: 'Important contact numbers',
          onTap: () => _showEmergencyNumbers(context),
        ),
        _ActionCard(
          icon: Icons.feedback_outlined,
          title: 'Raise a Complaint',
          subtitle: 'Submit a formal complaint',
          onTap: () => context.push(AppRoutes.supportTickets),
        ),
        _ActionCard(
          icon: Icons.bug_report_outlined,
          title: 'Report a Bug',
          subtitle: 'Help us improve VoltShare',
          onTap: () => context.push(AppRoutes.supportTickets),
        ),
        _ActionCard(
          icon: Icons.lightbulb_outlined,
          title: 'Feature Request',
          subtitle: 'Suggest a new feature',
          onTap: () => context.push(AppRoutes.supportTickets),
        ),

        const SizedBox(height: 16),
        const Divider(),

        // === LEGAL & ABOUT ===
        const SizedBox(height: 8),
        Text(
          'Legal & About',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),

        _ActionCard(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          subtitle: 'How we protect your data',
          onTap: () => _showInfo(
            context,
            'Privacy Policy',
            'VoltShare takes your privacy seriously. We collect only the information needed to provide energy trading services. Your personal data is encrypted and never shared with third parties without your consent.',
          ),
        ),
        _ActionCard(
          icon: Icons.description_outlined,
          title: 'Terms & Conditions',
          subtitle: 'Terms of service for VoltShare',
          onTap: () => _showInfo(
            context,
            'Terms & Conditions',
            'By using VoltShare, you agree to our terms. Users must be verified to trade energy. The platform facilitates peer-to-peer energy trading but does not guarantee energy availability.',
          ),
        ),
        _ActionCard(
          icon: Icons.info_outline,
          title: 'About VoltShare',
          subtitle: 'Learn about our mission',
          onTap: () => _showInfo(
            context,
            'About VoltShare',
            'VoltShare is a decentralized energy trading platform that connects energy producers with consumers. Our mission is to make renewable energy accessible, affordable, and reliable for everyone.',
          ),
        ),

        const SizedBox(height: 24),

        // Logout
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isSigningOut ? null : onLogout,
            icon: Icon(isSigningOut ? Icons.hourglass_empty : Icons.logout),
            label: Text(isSigningOut ? 'Logging out...' : 'Log out'),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  void _showFAQ(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _FAQSheet(),
    );
  }

  void _showEmergencyNumbers(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (context) => _EmergencyNumbersSheet(),
    );
  }

  void _showInfo(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
        dense: true,
      ),
    );
  }
}

class _FAQSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Frequently Asked Questions',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                _FAQItem(
                  question: 'How do I buy energy?',
                  answer:
                      'Navigate to the Marketplace tab, browse available listings, select one that meets your needs, and click "Buy". You need sufficient wallet balance and approved KYC.',
                ),
                _FAQItem(
                  question: 'How do I sell energy?',
                  answer:
                      'Producers can create listings from the "Create Listing" option. Set your price per kWh, available quantity, and schedule. KYC verification is required first.',
                ),
                _FAQItem(
                  question: 'How does payment work?',
                  answer:
                      'Payments are handled through the escrow system. When you buy energy, funds are held in escrow until the energy is delivered. Then the payment is released to the seller.',
                ),
                _FAQItem(
                  question: 'What is KYC?',
                  answer:
                      'Know Your Customer (KYC) is identity verification. All users must complete KYC before buying or selling energy on the marketplace.',
                ),
                _FAQItem(
                  question: 'How does the Emergency Assistance feature work?',
                  answer:
                      'Consumers can request immediate energy assistance during emergencies like medical needs, natural disasters, or power outages. Admin reviews and allocates energy from emergency reserves.',
                ),
                _FAQItem(
                  question: 'How do I reset my password?',
                  answer:
                      'Go to the login screen and tap "Forgot Password". Enter your registered email address and follow the instructions sent to your inbox.',
                ),
                _FAQItem(
                  question: 'How is my data protected?',
                  answer:
                      'VoltShare uses encryption for all data transmission. We follow industry best practices for data security and comply with applicable privacy regulations.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;
  const _FAQItem({required this.question, required this.answer});
  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                Text(
                  widget.answer,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyNumbersSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.7,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Emergency Numbers',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                _EmergencyTile(
                  number: '108',
                  title: 'Emergency Services',
                  subtitle: 'Ambulance, Fire, Police',
                  icon: Icons.emergency,
                  color: Colors.red,
                ),
                _EmergencyTile(
                  number: '112',
                  title: 'National Emergency',
                  subtitle: 'All emergencies (India)',
                  icon: Icons.phone_in_talk,
                  color: Colors.orange,
                ),
                _EmergencyTile(
                  number: '101',
                  title: 'Fire Brigade',
                  subtitle: 'Fire emergencies',
                  icon: Icons.fire_hydrant,
                  color: Colors.deepOrange,
                ),
                _EmergencyTile(
                  number: '102',
                  title: 'Ambulance',
                  subtitle: 'Medical emergencies',
                  icon: Icons.local_hospital,
                  color: Colors.red.shade700,
                ),
                _EmergencyTile(
                  number: '100',
                  title: 'Police',
                  subtitle: 'Police assistance',
                  icon: Icons.local_police,
                  color: Colors.blue,
                ),
                _EmergencyTile(
                  number: '1916',
                  title: 'VoltShare Emergency',
                  subtitle: 'Energy assistance hotline',
                  icon: Icons.bolt,
                  color: Colors.amber.shade700,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyTile extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _EmergencyTile({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            number,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
