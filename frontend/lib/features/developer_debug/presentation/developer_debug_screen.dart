import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../authentication/data/auth_repository.dart';

class DeveloperDebugScreen extends ConsumerStatefulWidget {
  const DeveloperDebugScreen({super.key});

  @override
  ConsumerState<DeveloperDebugScreen> createState() =>
      _DeveloperDebugScreenState();
}

class _DeveloperDebugScreenState extends ConsumerState<DeveloperDebugScreen> {
  final Map<String, _DebugResponse> _responses = {};
  final Map<String, bool> _diagnostics = {};
  bool _isRefreshingSession = false;
  bool _isRunningDiagnostics = false;
  String? _statusMessage;

  String get _apiBaseUrl => ref.read(appConfigProvider).apiBaseUrl;
  String get _backendBaseUrl =>
      _apiBaseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final repository = ref.watch(authRepositoryProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final user = repository.currentUser;
    final session = repository.currentSession;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final expiry = session?.expiresAt == null
        ? 'Not available'
        : DateTime.fromMillisecondsSinceEpoch(
            session!.expiresAt! * 1000,
          ).toLocal().toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Debug'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ConnectionBanner(
            connected: _responses['health']?.ok,
            message: _statusMessage,
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Session',
            children: [
              _InfoRow('Current user ID', user?.id ?? 'Not signed in'),
              _InfoRow(
                'Email',
                profile?.email ?? user?.email ?? 'Not available',
              ),
              _InfoRow(
                'Full name',
                profile?.fullName ??
                    metadata['full_name']?.toString() ??
                    'Not available',
              ),
              _InfoRow(
                'Role',
                profile?.role.value ??
                    metadata['role']?.toString() ??
                    'Not available',
              ),
              _TokenRow(
                label: 'Access Token',
                value: session?.accessToken ?? '',
                onCopy: () => _copy(session?.accessToken ?? ''),
              ),
              _TokenRow(
                label: 'Refresh Token',
                value: session?.refreshToken ?? '',
                onCopy: () => _copy(session?.refreshToken ?? ''),
              ),
              _InfoRow('Session expiry time', expiry),
              _InfoRow('API Base URL', config.apiBaseUrl),
              _InfoRow('USE_MOCK_BACKEND', config.useMockBackend.toString()),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Actions',
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _copy(session?.accessToken ?? ''),
                    icon: const Icon(Icons.key),
                    label: const Text('Copy Access Token'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _copy(session?.refreshToken ?? ''),
                    icon: const Icon(Icons.vpn_key_outlined),
                    label: const Text('Copy Refresh Token'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isRefreshingSession ? null : _refreshSession,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      _isRefreshingSession
                          ? 'Refreshing...'
                          : 'Refresh Session',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _open('$_backendBaseUrl/docs'),
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Open Swagger (/docs)'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      _open('$_backendBaseUrl/health');
                      _fetchHealth();
                    },
                    icon: const Icon(Icons.monitor_heart_outlined),
                    label: const Text('Open Health Endpoint'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      _open('$_apiBaseUrl/dashboard');
                      _fetchApi('dashboard', '/dashboard');
                    },
                    icon: const Icon(Icons.dashboard_outlined),
                    label: const Text('Open Dashboard Endpoint'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isRunningDiagnostics ? null : _runDiagnostics,
            icon: const Icon(Icons.fact_check_outlined),
            label: Text(
              _isRunningDiagnostics
                  ? 'Running diagnostics...'
                  : 'Run Backend Diagnostics',
            ),
          ),
          if (_diagnostics.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DiagnosticsPanel(items: _diagnostics),
          ],
          const SizedBox(height: 12),
          _EndpointCard(
            title: 'GET /health',
            response: _responses['health'],
            onRun: _fetchHealth,
            onCopy: () => _copyJson('health'),
          ),
          const SizedBox(height: 12),
          _EndpointCard(
            title: 'GET /auth/me',
            response: _responses['authMe'],
            onRun: () => _fetchApi('authMe', '/auth/me'),
            onCopy: () => _copyJson('authMe'),
          ),
          const SizedBox(height: 12),
          _EndpointCard(
            title: 'GET /dashboard',
            response: _responses['dashboard'],
            onRun: () => _fetchApi('dashboard', '/dashboard'),
            onCopy: () => _copyJson('dashboard'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchHealth() async {
    try {
      final uri = Uri.parse('$_backendBaseUrl/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      _setResponse(
        'health',
        _DebugResponse(
          ok: response.statusCode >= 200 && response.statusCode < 300,
          statusCode: response.statusCode,
          json: _decodeBody(response.body),
        ),
      );
    } catch (error) {
      _setResponse('health', _DebugResponse.error(error.toString()));
    }
  }

  Future<void> _fetchApi(String key, String path) async {
    try {
      final data = await ref.read(apiClientProvider).get(path);
      _setResponse(key, _DebugResponse(ok: true, statusCode: 200, json: data));
    } catch (error) {
      _setResponse(key, _DebugResponse.error(error.toString()));
    }
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isRunningDiagnostics = true;
      _diagnostics.clear();
    });
    await _fetchHealth();
    _diagnostics['API reachable'] = _responses['health']?.ok ?? false;
    await _fetchApi('authMe', '/auth/me');
    final authOk = _responses['authMe']?.ok ?? false;
    _diagnostics['JWT valid'] = authOk;
    _diagnostics['User authenticated'] = authOk;
    await _fetchApi('dashboard', '/dashboard');
    _diagnostics['Dashboard loaded'] = _responses['dashboard']?.ok ?? false;
    await _fetchApi('marketplace', '/marketplace/summary');
    _diagnostics['Marketplace available'] =
        _responses['marketplace']?.ok ?? false;
    await _fetchApi('wallet', '/wallet');
    _diagnostics['Wallet available'] = _responses['wallet']?.ok ?? false;
    if (mounted) {
      setState(() => _isRunningDiagnostics = false);
    }
  }

  Future<void> _refreshSession() async {
    setState(() => _isRefreshingSession = true);
    try {
      await ref.read(authRepositoryProvider).refreshSession();
      setState(() => _statusMessage = 'Session refreshed.');
    } catch (error) {
      setState(() => _statusMessage = 'Refresh failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isRefreshingSession = false);
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await _copy(url);
      setState(() => _statusMessage = 'Could not open browser. URL copied.');
    }
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
    }
  }

  Future<void> _copyJson(String key) async {
    final response = _responses[key];
    if (response == null) {
      return;
    }
    await _copy(response.prettyJson);
  }

  void _setResponse(String key, _DebugResponse response) {
    if (!mounted) {
      return;
    }
    setState(() {
      _responses[key] = response;
      if (key == 'health') {
        _statusMessage = response.ok
            ? 'Backend reachable.'
            : 'Backend offline.';
      }
    });
  }

  Object? _decodeBody(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }
}

class _DebugResponse {
  const _DebugResponse({
    required this.ok,
    required this.statusCode,
    required this.json,
  });

  factory _DebugResponse.error(String message) {
    return _DebugResponse(
      ok: false,
      statusCode: null,
      json: {'error': message},
    );
  }

  final bool ok;
  final int? statusCode;
  final Object? json;

  String get prettyJson {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.connected, required this.message});

  final bool? connected;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final isConnected = connected == true;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isConnected ? Colors.green.shade300 : Colors.red.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              isConnected ? Icons.check_circle : Icons.cancel,
              color: isConnected ? Colors.green.shade700 : Colors.red.shade700,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${isConnected ? 'Connected' : 'Offline'}${message == null ? '' : ' - $message'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _TokenRow extends StatelessWidget {
  const _TokenRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final display = value.isEmpty ? 'Not available' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: SelectableText(display, maxLines: 3, minLines: 1)),
          IconButton(
            tooltip: 'Copy',
            onPressed: value.isEmpty ? null : onCopy,
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
    );
  }
}

class _EndpointCard extends StatelessWidget {
  const _EndpointCard({
    required this.title,
    required this.response,
    required this.onRun,
    required this.onCopy,
  });

  final String title;
  final _DebugResponse? response;
  final VoidCallback onRun;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final item = response;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Run',
                  onPressed: onRun,
                  icon: const Icon(Icons.play_arrow),
                ),
                IconButton(
                  tooltip: 'Copy JSON',
                  onPressed: item == null ? null : onCopy,
                  icon: const Icon(Icons.copy_all),
                ),
              ],
            ),
            if (item != null) ...[
              Chip(
                avatar: Icon(
                  item.ok ? Icons.check : Icons.close,
                  size: 18,
                  color: item.ok ? Colors.green : Colors.red,
                ),
                label: Text(
                  item.statusCode == null
                      ? (item.ok ? 'OK' : 'Failed')
                      : 'HTTP ${item.statusCode}',
                ),
              ),
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    item.prettyJson,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DiagnosticsPanel extends StatelessWidget {
  const _DiagnosticsPanel({required this.items});

  final Map<String, bool> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Diagnostics', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final entry in items.entries)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  entry.value ? Icons.check_circle : Icons.error,
                  color: entry.value ? Colors.green : Colors.red,
                ),
                title: Text(entry.key),
              ),
          ],
        ),
      ),
    );
  }
}
