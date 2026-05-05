import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/auth_context.dart';
import '../services/script_service.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  bool _isSavingProfile = false;
  bool _seededProfile = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile(AuthContextController auth) async {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();

    if (first.isEmpty || last.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('First and last name are required.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSavingProfile = true);

    try {
      await auth.updateProfile(firstName: first, lastName: last);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _updatePreference(String key, dynamic value) async {
    await ScriptService.updateUserSettings({key: value});
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final profile = auth.profile ?? <String, dynamic>{};

    if (!_seededProfile) {
      _firstNameController.text = (profile['firstName'] as String?) ?? '';
      _lastNameController.text = (profile['lastName'] as String?) ?? '';
      _seededProfile = true;
    }

    final createdAt = profile['createdAt'];
    String createdLabel = 'Unknown';
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      createdLabel =
          '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontFamily: 'Georgia',
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your account and rehearsal preferences',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Profile', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _buildField(label: 'Email', value: auth.email, readOnly: true),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(label: 'First name', controller: _firstNameController),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildField(label: 'Last name', controller: _lastNameController),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Member since: $createdLabel',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _isSavingProfile ? null : () => _saveProfile(auth),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC107),
                      foregroundColor: Colors.black,
                    ),
                    child: _isSavingProfile
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text('Save profile'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: ScriptService.getUserSettings(),
            builder: (context, snapshot) {
              final settings = snapshot.data?.data() ?? <String, dynamic>{};
              final reminderEnabled = (settings['reminderEnabled'] as bool?) ?? false;
              final challengeModeDefault = (settings['challengeModeDefault'] as bool?) ?? false;
              final autoSaveSessions = (settings['autoSaveSessions'] as bool?) ?? true;
              final preferredTtsSpeed = (settings['preferredTtsSpeed'] as num?)?.toDouble() ?? 1.0;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rehearsal preferences',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _buildSwitchRow(
                      title: 'Practice reminders',
                      subtitle: 'Allow reminder prompts for inactive periods.',
                      value: reminderEnabled,
                      onChanged: (value) => _updatePreference('reminderEnabled', value),
                    ),
                    _buildSwitchRow(
                      title: 'Default challenge mode',
                      subtitle: 'Hide your lines by default in rehearsal.',
                      value: challengeModeDefault,
                      onChanged: (value) => _updatePreference('challengeModeDefault', value),
                    ),
                    _buildSwitchRow(
                      title: 'Auto-save sessions',
                      subtitle: 'Store completed sessions in your progress history.',
                      value: autoSaveSessions,
                      onChanged: (value) => _updatePreference('autoSaveSessions', value),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Preferred TTS speed: ${preferredTtsSpeed.toStringAsFixed(1)}x',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Slider(
                      value: preferredTtsSpeed,
                      min: 0.5,
                      max: 2.0,
                      divisions: 6,
                      activeColor: const Color(0xFFFFC107),
                      onChanged: (value) {
                        _updatePreference('preferredTtsSpeed', double.parse(value.toStringAsFixed(1)));
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: OutlinedButton.icon(
              onPressed: auth.signOut,
              icon: const Icon(Icons.logout, color: Colors.white70),
              label: const Text('Sign out', style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    TextEditingController? controller,
    String? value,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          initialValue: controller == null ? value : null,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFFFFC107)),
        ],
      ),
    );
  }
}
