import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/emergency_provider.dart';

class EmergencyFormScreen extends ConsumerStatefulWidget {
  const EmergencyFormScreen({super.key});

  @override
  ConsumerState<EmergencyFormScreen> createState() =>
      _EmergencyFormScreenState();
}

class _EmergencyFormScreenState extends ConsumerState<EmergencyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _energyController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCategory = 'Medical';
  String _selectedPriority = 'Critical';
  bool _submitting = false;

  static const _categories = [
    'Medical',
    'Natural Disaster',
    'Fire',
    'Flood',
    'Hospital',
    'Government Relief',
    'Other',
  ];

  static const _priorities = ['Low', 'Medium', 'High', 'Critical'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _energyController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Assistance'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning banner
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Use this form only for genuine emergencies requiring immediate energy assistance.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Section header
              Text(
                'Emergency Details',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g., Medical Emergency - Life Support',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Title is required'
                    : null,
              ),
              const SizedBox(height: 12),

              // Category
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
              const SizedBox(height: 12),

              // Priority
              DropdownButtonFormField<String>(
                value: _selectedPriority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag),
                ),
                items: _priorities
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedPriority = v!),
              ),
              const SizedBox(height: 12),

              // Energy required
              TextFormField(
                controller: _energyController,
                decoration: const InputDecoration(
                  labelText: 'Required Energy (kWh)',
                  hintText: 'e.g., 10',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.bolt),
                  suffixText: 'kWh',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty)
                    return 'Energy required is required';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0)
                    return 'Enter a valid positive number';
                  if (n > 10000) return 'Maximum 10,000 kWh';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe your emergency situation in detail...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (v) => (v == null || v.trim().length < 10)
                    ? 'Describe your emergency (min 10 characters)'
                    : null,
              ),
              const SizedBox(height: 20),

              Text(
                'Contact Information',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              // Phone
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+91-9876543210',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),

              // Address
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Location / Address',
                  hintText: 'Your current location or address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              Text(
                'Additional Information',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes (Optional)',
                  hintText: 'Any other information that might help...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submitRequest,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _submitting ? 'Submitting...' : 'Submit Emergency Request',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Emergency info
              Center(
                child: Text(
                  'An admin will review your request and respond as soon as possible.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final data = {
        'title': _titleController.text.trim(),
        'category': _selectedCategory,
        'description': _descriptionController.text.trim(),
        'required_energy_kwh': double.parse(_energyController.text.trim()),
        'priority': _selectedPriority,
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      };

      final result = await ref
          .read(emergencyProvider.notifier)
          .createRequest(data);
      if (!mounted) return;

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Emergency request submitted successfully!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit request. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
