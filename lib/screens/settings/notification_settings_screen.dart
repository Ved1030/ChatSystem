import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../repositories/user_repository.dart';
import '../../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final UserRepository _userRepository = UserRepository();
  bool _notificationsEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    final user = await _userRepository.getUser(currentUid);
    if (mounted) {
      setState(() {
        _notificationsEnabled = user?.notificationsEnabled ?? true;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    setState(() => _notificationsEnabled = value);

    if (value) {
      final token = NotificationService().currentToken;
      await _userRepository.updateUser(currentUid, {
        'fcmToken': token,
        'notificationsEnabled': true,
      });
    } else {
      await _userRepository.updateUser(currentUid, {
        'notificationsEnabled': false,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection('Message Notifications'),
                const SizedBox(height: 8),
                _buildToggleTile(
                  icon: Icons.notifications_rounded,
                  iconColor: const Color(0xFF4CAF50),
                  title: 'Show Notifications',
                  subtitle: 'Receive notifications for new messages',
                  value: _notificationsEnabled,
                  onChanged: _toggleNotifications,
                ),
                const SizedBox(height: 24),
                _buildSection('Sounds'),
                const SizedBox(height: 8),
                _buildTile(
                  icon: Icons.volume_up_rounded,
                  iconColor: const Color(0xFFFF9800),
                  title: 'Sound',
                  subtitle: 'Play sound for notifications',
                  trailing: Switch(
                    value: true,
                    activeTrackColor:
                        const Color(0xFF4CAF50).withValues(alpha: 0.4),
                    activeThumbColor: const Color(0xFF4CAF50),
                    onChanged: (_) {},
                  ),
                ),
                const SizedBox(height: 10),
                _buildTile(
                  icon: Icons.vibration_rounded,
                  iconColor: const Color(0xFF9C27B0),
                  title: 'Vibrate',
                  subtitle: 'Vibrate on new notifications',
                  trailing: Switch(
                    value: true,
                    activeTrackColor:
                        const Color(0xFF4CAF50).withValues(alpha: 0.4),
                    activeThumbColor: const Color(0xFF4CAF50),
                    onChanged: (_) {},
                  ),
                ),
                const SizedBox(height: 24),
                _buildSection('Preview'),
                const SizedBox(height: 8),
                _buildTile(
                  icon: Icons.preview_rounded,
                  iconColor: const Color(0xFF2196F3),
                  title: 'Notification Preview',
                  subtitle: _notificationsEnabled
                      ? 'Show message preview in notifications'
                      : 'Notifications are currently disabled',
                  trailing: Switch(
                    value: _notificationsEnabled,
                    activeTrackColor:
                        const Color(0xFF4CAF50).withValues(alpha: 0.4),
                    activeThumbColor: const Color(0xFF4CAF50),
                    onChanged: _toggleNotifications,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1D26),
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Color(0xFF1A1D26),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: const Color(0xFF8E8E93).withValues(alpha: 0.8),
            fontSize: 13,
          ),
        ),
        trailing: trailing,
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _buildTile(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      trailing: Switch(
        value: value,
        activeTrackColor: iconColor.withValues(alpha: 0.4),
        activeThumbColor: iconColor,
        onChanged: onChanged,
      ),
    );
  }
}
