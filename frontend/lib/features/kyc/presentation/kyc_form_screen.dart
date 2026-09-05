import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/error_message.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/user_role.dart';
import '../data/kyc_repository.dart';
import '../domain/kyc_models.dart';
import '../providers/kyc_provider.dart';

class KycFormScreen extends ConsumerStatefulWidget {
  const KycFormScreen({super.key});

  @override
  ConsumerState<KycFormScreen> createState() => _KycFormScreenState();
}

enum _FormStep { personalInfo, identity, documents, review }


class _KycFormScreenState extends ConsumerState<KycFormScreen> {
  final _formKey = GlobalKey<FormState>();
  _FormStep _currentStep = _FormStep.personalInfo;

  // Controllers
  final _fullNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _pinCodeController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _plantLocationController = TextEditingController();
  final _utilityLicenseController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankIfscController = TextEditingController();
  final _bankHolderController = TextEditingController();

  // State variables
  DateTime? _dateOfBirth;
  String _gender = '';
  String _district = '';
  String _stateProvince = '';
  IdType _idType = IdType.aadhar;
  String _nameOnId = '';
  String _city = '';
  String _renewableSource = '';
  double? _installedCapacity;
  bool _isSubmitting = false;
  bool _declarationAccepted = false;
  String? _error;

  // Document selection tracking
  String? _selectedIdProofFileName;
  String? _selectedSelfieFileName;
  String? _selectedOwnershipFileName;

  bool get _isProducer {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    return profile?.role == UserRole.producer || profile?.role == UserRole.prosumer;
  }

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile != null) {
      _fullNameController.text = profile.fullName;
      _phoneController.text = profile.phone;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _addressController.dispose();
    _pinCodeController.dispose();
    _idNumberController.dispose();
    _phoneController.dispose();
    _plantLocationController.dispose();
    _utilityLicenseController.dispose();
    _bankAccountController.dispose();
    _bankIfscController.dispose();
    _bankHolderController.dispose();
    super.dispose();
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case _FormStep.personalInfo:
        if (_fullNameController.text.trim().isEmpty) return false;
        if (_dateOfBirth == null) return false;
        if (_district.trim().isEmpty) return false;
        if (_stateProvince.trim().isEmpty) return false;
        if (_pinCodeController.text.trim().isEmpty) return false;
        if (_phoneController.text.trim().isEmpty) return false;
        if (_addressController.text.trim().isEmpty) return false;
        return true;
      case _FormStep.identity:
        if (_idNumberController.text.trim().isEmpty) return false;
        return true;
      case _FormStep.documents:
        return true;
      case _FormStep.review:
        return _declarationAccepted;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile == null) {
      setState(() => _error = 'Profile not found. Please login again.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final submission = KycRecord(
        id: '',
        userId: profile.id,
        userRole: profile.role.value,
        fullName: _fullNameController.text.trim(),
        dateOfBirth: _dateOfBirth != null
            ? '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}'
            : '',
        address: _addressController.text.trim(),
        district: _district,
        state: _stateProvince,
        pinCode: _pinCodeController.text.trim(),
        idType: _idType.value,
        idNumber: _idNumberController.text.trim(),
        phone: _phoneController.text.trim(),
        status: KycStatus.pending,
        renewableEnergySource: _renewableSource.isNotEmpty ? _renewableSource : null,
        installedCapacityKw: _installedCapacity,
        plantLocation: _plantLocationController.text.isNotEmpty ? _plantLocationController.text.trim() : null,
        utilityLicenseNumber: _utilityLicenseController.text.isNotEmpty ? _utilityLicenseController.text.trim() : null,
        bankAccountNumber: _bankAccountController.text.isNotEmpty ? _bankAccountController.text.trim() : null,
        bankIfscCode: _bankIfscController.text.isNotEmpty ? _bankIfscController.text.trim() : null,
        bankAccountHolder: _bankHolderController.text.isNotEmpty ? _bankHolderController.text.trim() : null,
      );

      await ref.read(kycRepositoryProvider).submitKyc(submission);
      ref.invalidate(myKycProvider);
      ref.invalidate(kycStatusProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('KYC submitted successfully! Awaiting verification.')),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isProducer = profile?.role == UserRole.producer || profile?.role == UserRole.prosumer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('KYC Verification'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  // Progress Indicator
                  _buildProgressIndicator(theme),
                  // Stepper header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      _stepTitle(),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      _stepSubtitle(),
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Scrollable form content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_currentStep == _FormStep.personalInfo) _buildPersonalInfoStep(theme, isProducer),
                          if (_currentStep == _FormStep.identity) _buildIdentityStep(theme),
                          if (_currentStep == _FormStep.documents) _buildDocumentsStep(theme),
                          if (_currentStep == _FormStep.review) _buildReviewStep(theme, isProducer),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            ErrorMessage(message: _error!),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Bottom navigation
                  _buildBottomBar(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(ThemeData theme) {
    final steps = ['Personal', 'Identity', 'Docs', 'Review'];
    final stepIndex = _FormStep.values.indexOf(_currentStep);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i <= stepIndex;
          final isCurrent = i == stepIndex;
          return Expanded(
            child: Row(
              children: [
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isActive ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                    ),
                  ),
                Container(
                  width: isCurrent ? 32 : 28,
                  height: isCurrent ? 32 : 28,
                  decoration: BoxDecoration(
                    color: isActive ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    border: isCurrent ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        fontSize: isCurrent ? 14 : 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  String _stepTitle() {
    switch (_currentStep) {
      case _FormStep.personalInfo:
        return 'Personal Information';
      case _FormStep.identity:
        return 'Identity Details';
      case _FormStep.documents:
        return 'Document Upload';
      case _FormStep.review:
        return 'Review & Submit';
    }
  }

  String _stepSubtitle() {
    switch (_currentStep) {
      case _FormStep.personalInfo:
        return 'Provide your personal and address details';
      case _FormStep.identity:
        return 'Enter your government ID details';
      case _FormStep.documents:
        return 'Upload required identity documents';
      case _FormStep.review:
        return 'Verify all information before submission';
    }
  }

  Widget _buildPersonalInfoStep(ThemeData theme, bool isProducer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Full Name
        _buildLabel('Full Name *'),
        const SizedBox(height: 4),
        TextFormField(
          controller: _fullNameController,
          decoration: const InputDecoration(
            hintText: 'Enter your full name',
            prefixIcon: Icon(Icons.person_outline),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 16),

        // Date of Birth
        _buildLabel('Date of Birth *'),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime(2000),
              firstDate: DateTime(1950),
              lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
            );
            if (date != null) setState(() => _dateOfBirth = date);
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              hintText: 'Select your date of birth',
              prefixIcon: Icon(Icons.calendar_today_outlined),
            ),
            child: Text(
              _dateOfBirth != null
                  ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                  : '',
              style: TextStyle(
                color: _dateOfBirth != null ? null : theme.hintColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Gender
        _buildLabel('Gender'),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _gender.isEmpty ? null : _gender,
          decoration: const InputDecoration(
            hintText: 'Select gender',
            prefixIcon: Icon(Icons.wc_outlined),
          ),
          items: const [
            DropdownMenuItem(value: 'Male', child: Text('Male')),
            DropdownMenuItem(value: 'Female', child: Text('Female')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
            DropdownMenuItem(value: 'Prefer not to say', child: Text('Prefer not to say')),
          ],
          onChanged: (v) => setState(() => _gender = v ?? ''),
        ),
        const SizedBox(height: 16),

        // Phone
        _buildLabel('Phone Number *'),
        const SizedBox(height: 4),
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            hintText: '10-digit mobile number',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          keyboardType: TextInputType.phone,
          maxLength: 10,
          onChanged: (_) => setState(() {}),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v.trim())) return 'Enter valid 10-digit number';
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Email
        _buildLabel('Email'),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: ref.read(currentProfileProvider).valueOrNull?.email ?? '',
          decoration: const InputDecoration(
            hintText: 'Email address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          readOnly: true,
          enabled: false,
        ),
        const SizedBox(height: 20),

        // Address section
        Text('Address', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
        const SizedBox(height: 12),

        _buildLabel('Address Line 1 *'),
        const SizedBox(height: 4),
        TextFormField(
          controller: _addressController,
          decoration: const InputDecoration(
            hintText: 'Street, building, area',
            prefixIcon: Icon(Icons.home_outlined),
          ),
          maxLines: 2,
          onChanged: (_) => setState(() {}),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 16),

        // District
        _buildLabel('District *'),
        const SizedBox(height: 4),
        TextFormField(
          decoration: const InputDecoration(
            hintText: 'Enter your district',
            prefixIcon: Icon(Icons.map_outlined),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => setState(() => _district = v),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 16),

        // City
        _buildLabel('City'),
        const SizedBox(height: 4),
        TextFormField(
          decoration: const InputDecoration(
            hintText: 'Enter your city',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => setState(() => _city = v),
        ),
        const SizedBox(height: 16),

        // State
        _buildLabel('State *'),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _stateProvince.isEmpty ? null : _stateProvince,
          decoration: const InputDecoration(
            hintText: 'Select your state',
            prefixIcon: Icon(Icons.public_outlined),
          ),
          items: _indianStates.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => _stateProvince = v ?? ''),
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 16),

        // PIN Code
        _buildLabel('PIN Code *'),
        const SizedBox(height: 4),
        TextFormField(
          controller: _pinCodeController,
          decoration: const InputDecoration(
            hintText: '6-digit PIN code',
            prefixIcon: Icon(Icons.pin_outlined),
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
          onChanged: (_) => setState(() {}),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            if (!RegExp(r'^\d{6}$').hasMatch(v.trim())) return 'Enter valid 6-digit PIN';
            return null;
          },
        ),
        const SizedBox(height: 24),

        // Producer-specific fields
        if (isProducer) ...[
          Text('Producer Details', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.tertiary)),
          const SizedBox(height: 12),

          // Energy Source
          _buildLabel('Renewable Energy Source *'),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: _renewableSource.isEmpty ? null : _renewableSource,
            decoration: const InputDecoration(
              hintText: 'Select energy source',
              prefixIcon: Icon(Icons.eco_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'Solar', child: Text('Solar')),
              DropdownMenuItem(value: 'Wind', child: Text('Wind')),
              DropdownMenuItem(value: 'Hydro', child: Text('Hydro')),
              DropdownMenuItem(value: 'Biomass', child: Text('Biomass')),
              DropdownMenuItem(value: 'Hybrid', child: Text('Hybrid')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _renewableSource = v ?? ''),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          // Installed Capacity
          _buildLabel('Installed Capacity (kW) *'),
          const SizedBox(height: 4),
          TextFormField(
            decoration: const InputDecoration(
              hintText: 'e.g. 5',
              prefixIcon: Icon(Icons.speed_outlined),
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => _installedCapacity = double.tryParse(v),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              final val = double.tryParse(v);
              if (val == null || val <= 0) return 'Enter valid capacity';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Plant Location
          _buildLabel('Plant / Installation Location *'),
          const SizedBox(height: 4),
          TextFormField(
            controller: _plantLocationController,
            decoration: const InputDecoration(
              hintText: 'Address where installation is located',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          // Utility License
          _buildLabel('Utility / License Number (optional)'),
          const SizedBox(height: 4),
          TextFormField(
            controller: _utilityLicenseController,
            decoration: const InputDecoration(
              hintText: 'If applicable',
              prefixIcon: Icon(Icons.article_outlined),
            ),
          ),
          const SizedBox(height: 24),

          // Bank Details for Settlement
          Text('Bank Details for Settlement', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.tertiary)),
          const SizedBox(height: 12),

          _buildLabel('Account Holder Name *'),
          const SizedBox(height: 4),
          TextFormField(
            controller: _bankHolderController,
            decoration: const InputDecoration(
              hintText: 'Name as on bank account',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textCapitalization: TextCapitalization.words,
            validator: _isProducer ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
          ),
          const SizedBox(height: 16),

          _buildLabel('Bank Account Number *'),
          const SizedBox(height: 4),
          TextFormField(
            controller: _bankAccountController,
            decoration: const InputDecoration(
              hintText: 'Enter account number',
              prefixIcon: Icon(Icons.account_balance_outlined),
            ),
            keyboardType: TextInputType.number,
            validator: _isProducer ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
          ),
          const SizedBox(height: 16),

          _buildLabel('IFSC Code *'),
          const SizedBox(height: 4),
          TextFormField(
            controller: _bankIfscController,
            decoration: const InputDecoration(
              hintText: 'e.g. SBIN0001234',
              prefixIcon: Icon(Icons.code_outlined),
            ),
            textCapitalization: TextCapitalization.characters,
            validator: _isProducer ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
          ),
        ],
      ],
    );
  }

  Widget _buildIdentityStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ID Type
        _buildLabel('Government ID Type *'),
        const SizedBox(height: 4),
        DropdownButtonFormField<IdType>(
          value: _idType,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          items: IdType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
          onChanged: (v) => setState(() => _idType = v ?? IdType.aadhar),
        ),
        const SizedBox(height: 16),

        // ID Number
        _buildLabel('ID Number *'),
        const SizedBox(height: 4),
        TextFormField(
          controller: _idNumberController,
          decoration: InputDecoration(
            hintText: 'Enter your ${_idType.label} number',
            prefixIcon: const Icon(Icons.tag_outlined),
          ),
          onChanged: (_) => setState(() {}),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            if (v.trim().length < 4) return 'Enter valid ID number';
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Name on ID
        _buildLabel('Name as on ID *'),
        const SizedBox(height: 4),
        TextFormField(
          decoration: const InputDecoration(
            hintText: 'Name exactly as shown on ID',
            prefixIcon: Icon(Icons.text_fields_outlined),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => setState(() => _nameOnId = v),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildDocumentsStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upload the following documents to verify your identity.',
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 20),

        // ID Proof
        _buildLabel('Government ID Proof *'),
        const SizedBox(height: 4),
        _buildDocumentTile(
          icon: Icons.credit_card_outlined,
          title: 'Front Image of ID',
          subtitle: _selectedIdProofFileName ?? 'Upload a clear image of your ID card',
          onSelect: () => setState(() => _selectedIdProofFileName = _selectedIdProofFileName ?? 'id_proof_selected.png'),
        ),
        const SizedBox(height: 16),

        // Selfie
        _buildLabel('Selfie Photo *'),
        const SizedBox(height: 4),
        _buildDocumentTile(
          icon: Icons.camera_alt_outlined,
          title: 'Your Selfie',
          subtitle: _selectedSelfieFileName ?? 'Upload a clear selfie holding your ID (optional)',
          onSelect: () => setState(() => _selectedSelfieFileName = _selectedSelfieFileName ?? 'selfie_selected.png'),
        ),
        const SizedBox(height: 16),

        if (_isProducer) ...[
          _buildLabel('Ownership / Installation Proof *'),
          const SizedBox(height: 4),
          _buildDocumentTile(
            icon: Icons.description_outlined,
            title: 'Energy Installation Proof',
            subtitle: _selectedOwnershipFileName ?? 'Upload energy installation ownership document',
            onSelect: () => setState(() => _selectedOwnershipFileName = _selectedOwnershipFileName ?? 'ownership_selected.png'),
          ),
        ],

        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: theme.colorScheme.tertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Documents are stored securely. Only authorised reviewers can access them.',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onTertiaryContainer),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep(ThemeData theme, bool isProducer) {
    final dateStr = _dateOfBirth != null
        ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
        : 'Not provided';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Personal info summary
        _buildReviewSection(theme, 'Personal Information', [
          _reviewRow('Full Name', _fullNameController.text.trim()),
          _reviewRow('Date of Birth', dateStr),
          _reviewRow('Gender', _gender.isEmpty ? 'Not provided' : _gender),
          _reviewRow('Phone', _phoneController.text.trim()),
          _reviewRow('Address', _addressController.text.trim()),
          _reviewRow('City', _city.isEmpty ? 'Not provided' : _city),
          _reviewRow('District', _district),
          _reviewRow('State', _stateProvince),
          _reviewRow('PIN Code', _pinCodeController.text.trim()),
        ]),

        const SizedBox(height: 16),
        _buildReviewSection(theme, 'Identity Details', [
          _reviewRow('ID Type', _idType.label),
          _reviewRow('ID Number', '••••${_idNumberController.text.length > 4 ? _idNumberController.text.substring(_idNumberController.text.length - 4) : _idNumberController.text}'),
          _reviewRow('Name on ID', _nameOnId.isEmpty ? _fullNameController.text.trim() : _nameOnId),
          _reviewRow('ID Proof', _selectedIdProofFileName ?? 'Not uploaded'),
          _reviewRow('Selfie', _selectedSelfieFileName ?? 'Not uploaded'),
        ]),

        if (isProducer) ...[
          const SizedBox(height: 16),
          _buildReviewSection(theme, 'Producer Details', [
            _reviewRow('Energy Source', _renewableSource.isEmpty ? 'Not specified' : _renewableSource),
            _reviewRow('Capacity', _installedCapacity != null ? '${_installedCapacity} kW' : 'Not specified'),
            _reviewRow('Plant Location', _plantLocationController.text.isEmpty ? 'Not specified' : _plantLocationController.text.trim()),
            _reviewRow('Ownership Proof', _selectedOwnershipFileName ?? 'Not uploaded'),
          ]),
        ],

        const SizedBox(height: 24),

        // Declaration
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.primaryContainer),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Declaration', style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'I confirm that the information provided above is true and correct to the best of my knowledge. '
                'I authorize VoltShare to verify my identity using the submitted documents.',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _declarationAccepted,
                onChanged: (v) => setState(() => _declarationAccepted = v ?? false),
                title: Text('I accept the above declaration', style: const TextStyle(fontSize: 14)),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          if (_currentStep != _FormStep.personalInfo)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    if (_currentStep == _FormStep.identity) _currentStep = _FormStep.personalInfo;
                    else if (_currentStep == _FormStep.documents) _currentStep = _FormStep.identity;
                    else if (_currentStep == _FormStep.review) _currentStep = _FormStep.documents;
                  });
                },
                child: const Text('Back'),
              ),
            ),
          if (_currentStep != _FormStep.personalInfo) const SizedBox(width: 12),
          Expanded(
            child: _currentStep == _FormStep.review
                ? FilledButton.icon(
                    onPressed: (_isSubmitting || !_validateCurrentStep()) ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.verified_outlined),
                    label: Text(_isSubmitting ? 'Submitting...' : 'Submit KYC'),
                  )
                : FilledButton(
                    onPressed: _validateCurrentStep()
                        ? () {
                            setState(() {
                              if (_currentStep == _FormStep.personalInfo) _currentStep = _FormStep.identity;
                              else if (_currentStep == _FormStep.identity) _currentStep = _FormStep.documents;
                              else if (_currentStep == _FormStep.documents) _currentStep = _FormStep.review;
                            });
                          }
                        : null,
                    child: const Text('Continue'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildDocumentTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onSelect,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.upload_file_outlined, size: 20),
        onTap: onSelect,
        dense: true,
      ),
    );
  }

  Widget _buildReviewSection(ThemeData theme, String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: theme.colorScheme.primary)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  static const _indianStates = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand',
    'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur',
    'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab',
    'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura',
    'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
    'Andaman and Nicobar Islands', 'Chandigarh', 'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi', 'Jammu and Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry',
  ];
}
