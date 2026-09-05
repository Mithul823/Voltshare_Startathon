import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../authentication/data/auth_repository.dart';

class SimpleTabScreen extends ConsumerStatefulWidget {
  const SimpleTabScreen({
    required this.title,
    required this.icon,
    required this.message,
    this.showLogout = false,
    super.key,
  });

  final String title;
  final IconData icon;
  final String message;
  final bool showLogout;

  @override
  ConsumerState<SimpleTabScreen> createState() => _SimpleTabScreenState();
}

class _SimpleTabScreenState extends ConsumerState<SimpleTabScreen> {
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
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(widget.message, textAlign: TextAlign.center),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (widget.showLogout) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isSigningOut ? null : _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
