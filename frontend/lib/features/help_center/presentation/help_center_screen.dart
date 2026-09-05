import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Text(
            'How can we help you?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Find answers, get support, and learn more about VoltShare.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Quick actions
          _SectionHeader(title: 'Quick Actions'),
          const SizedBox(height: 8),
          _QuickActionCard(
            icon: Icons.question_answer_outlined,
            title: 'Frequently Asked Questions',
            subtitle: 'Find answers to common questions',
            onTap: () => _showFAQ(context),
          ),
          _QuickActionCard(
            icon: Icons.headset_mic_outlined,
            title: 'Contact Support',
            subtitle: 'Get help from our support team',
            onTap: () => context.push(AppRoutes.supportTickets),
          ),
          _QuickActionCard(
            icon: Icons.phone_in_talk_outlined,
            title: 'Emergency Numbers',
            subtitle: 'Important contact numbers',
            onTap: () => _showEmergencyNumbers(context),
          ),
          const SizedBox(height: 24),

          // Feedback & Legal
          _SectionHeader(title: 'Feedback & Legal'),
          const SizedBox(height: 8),
          _QuickActionCard(
            icon: Icons.feedback_outlined,
            title: 'Raise a Complaint',
            subtitle: 'Submit a formal complaint',
            onTap: () => context.push(AppRoutes.supportTickets),
          ),
          _QuickActionCard(
            icon: Icons.bug_report_outlined,
            title: 'Report a Bug',
            subtitle: 'Help us improve VoltShare',
            onTap: () => context.push(AppRoutes.supportTickets),
          ),
          _QuickActionCard(
            icon: Icons.lightbulb_outlined,
            title: 'Feature Request',
            subtitle: 'Suggest a new feature',
            onTap: () => context.push(AppRoutes.supportTickets),
          ),
          const SizedBox(height: 24),

          // About
          _SectionHeader(title: 'About'),
          const SizedBox(height: 8),
          _QuickActionCard(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'How we protect your data',
            onTap: () => _showInfo(
              context,
              'Privacy Policy',
              'VoltShare takes your privacy seriously. We collect only the information needed to provide energy trading services. Your personal data is encrypted and never shared with third parties without your consent. For full details, please contact our support team.',
            ),
          ),
          _QuickActionCard(
            icon: Icons.description_outlined,
            title: 'Terms & Conditions',
            subtitle: 'Terms of service for VoltShare',
            onTap: () => _showInfo(
              context,
              'Terms & Conditions',
              'By using VoltShare, you agree to our terms. Users must be verified to trade energy. The platform facilitates peer-to-peer energy trading but does not guarantee energy availability. All transactions are subject to platform fees. See full terms on our website.',
            ),
          ),
          _QuickActionCard(
            icon: Icons.info_outline,
            title: 'About VoltShare',
            subtitle: 'Learn about our mission',
            onTap: () => _showInfo(
              context,
              'About VoltShare',
              'VoltShare is a decentralized energy trading platform that connects energy producers with consumers. Our mission is to make renewable energy accessible, affordable, and reliable for everyone. We leverage blockchain technology and AI to create a transparent, efficient energy marketplace.',
            ),
          ),
        ],
      ),
    );
  }

  void _showFAQ(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _FAQSheet(),
    );
  }

  void _showEmergencyNumbers(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (context) => const _EmergencyNumbersSheet(),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _FAQSheet extends StatelessWidget {
  const _FAQSheet();

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
                      'Navigate to the Marketplace tab, browse available listings, select one that meets your needs, and click "Buy". You need sufficient wallet balance to complete the purchase.',
                ),
                _FAQItem(
                  question: 'How do I sell energy?',
                  answer:
                      'Producers can create listings from the "Create Listing" option. Set your price per kWh, available quantity, and schedule. Once approved, buyers can purchase your energy.',
                ),
                _FAQItem(
                  question: 'How does payment work?',
                  answer:
                      'Payments are handled through the escrow system. When you buy energy, funds are held in escrow until the energy is delivered. Then the payment is released to the seller.',
                ),
                _FAQItem(
                  question: 'What is the Emergency Assistance feature?',
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
  const _EmergencyNumbersSheet();

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
                _EmergencyNumberTile(
                  number: '108',
                  title: 'Emergency Services',
                  subtitle: 'Ambulance, Fire, Police',
                  icon: Icons.emergency,
                  color: Colors.red,
                ),
                _EmergencyNumberTile(
                  number: '112',
                  title: 'National Emergency Number',
                  subtitle: 'All emergencies (India)',
                  icon: Icons.phone_in_talk,
                  color: Colors.orange,
                ),
                _EmergencyNumberTile(
                  number: '101',
                  title: 'Fire Brigade',
                  subtitle: 'Fire emergencies',
                  icon: Icons.fire_hydrant,
                  color: Colors.deepOrange,
                ),
                _EmergencyNumberTile(
                  number: '102',
                  title: 'Ambulance',
                  subtitle: 'Medical emergencies',
                  icon: Icons.local_hospital,
                  color: Colors.red.shade700,
                ),
                _EmergencyNumberTile(
                  number: '100',
                  title: 'Police',
                  subtitle: 'Police assistance',
                  icon: Icons.local_police,
                  color: Colors.blue,
                ),
                _EmergencyNumberTile(
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

class _EmergencyNumberTile extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _EmergencyNumberTile({
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
