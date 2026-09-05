import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/error_message.dart';
import '../data/auth_repository.dart';
import '../domain/user_role.dart';
import 'auth_form_helpers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _stateController = TextEditingController(text: 'Kerala');
  UserRole _role = UserRole.consumer;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .signUp(
            fullName: _fullNameController.text,
            email: _emailController.text,
            phone: _phoneController.text,
            password: _passwordController.text,
            role: _role,
            city: _cityController.text,
            district: _districtController.text,
            state: _stateController.text,
          );
      if (mounted) {
        context.go(AppRoutes.dashboard);
      }
    } on AppException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create account',              subtitle: 'Register as a consumer or producer.',
      showBackButton: true,
      fallbackRoute: AppRoutes.login,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            if (_error != null) ...[
              ErrorMessage(message: _error!),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (value) => requiredText(value, 'Full name'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: validateEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) => requiredText(value, 'Phone'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<UserRole>(
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(Icons.groups_outlined),
              ),
              items: [
                const DropdownMenuItem(
                  value: UserRole.consumer,
                  child: Text('consumer'),
                ),
                const DropdownMenuItem(
                  value: UserRole.producer,
                  child: Text('producer'),
                ),
              ],
              onChanged: (role) {
                if (role != null) {
                  setState(() => _role = role);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              validator: validatePassword,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: 'City'),
                    validator: (value) => requiredText(value, 'City'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _districtController,
                    decoration: const InputDecoration(labelText: 'District'),
                    validator: (value) => requiredText(value, 'District'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stateController,
              decoration: const InputDecoration(labelText: 'State'),
              validator: (value) => requiredText(value, 'State'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1),
              label: const Text('Register'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('Already have an account? Log in'),
            ),
          ],
        ),
      ),
    );
  }
}
