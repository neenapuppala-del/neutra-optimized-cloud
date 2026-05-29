import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationScheduler {
  static Timer? _timer;
  static final Set<String> _triggeredToday = {};
  static List<dynamic> _cachedNotifications = [];

  // Initialize notifications (noop now since we removed native setup)
  static Future<void> initialize() async {
    print("Notification Scheduler Initialized (In-App Only) ⏰");
  }

  // Start syncing notifications when the app starts
  static void start(BuildContext context) {
    if (_timer != null) return;

    print("Notification Scheduler Started ⏰");
    _loadCache();

    // Check every 2 seconds for perfect real-time precision without lag or network queries
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkNotifications(context);
    });
  }

  static Future<void> _loadCache() async {
    if (_cachedNotifications.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString('cached_notifications');
      if (dataStr != null) {
        _cachedNotifications = jsonDecode(dataStr) as List<dynamic>;
        print("Loaded ${_cachedNotifications.length} notifications from local cache");
      }
    } catch (e) {
      print("Error loading local notification cache: $e");
    }
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    print("Notification Scheduler Stopped 🛑");
  }

  static String _formatTime12Hour(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    var hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $period';
  }

  static String _normalize(String t) {
    t = t.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    if (t.startsWith('0')) {
      t = t.substring(1);
    }
    return t;
  }

  // Sync scheduled notifications globally in local cache
  static Future<void> scheduleAll(List<dynamic> customNotifications) async {
    _cachedNotifications = customNotifications;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_notifications', jsonEncode(customNotifications));
      print("In-app notifications synced and cached locally: ${customNotifications.length} active config(s)");
    } catch (e) {
      print("Error caching notifications: $e");
    }
  }

  static Future<void> _checkNotifications(BuildContext context) async {
    final now = DateTime.now();
    final formattedTime = _formatTime12Hour(now.hour, now.minute);
    final normalizedCurrent = _normalize(formattedTime);

    if (_cachedNotifications.isEmpty) {
      await _loadCache();
    }

    if (_cachedNotifications.isEmpty) return;

    for (var notif in _cachedNotifications) {
      final String id = notif['_id'] ?? '';
      final String title = notif['title'] ?? 'Reminder';
      final String notifTime = notif['time'] ?? '';
      final bool isOn = notif['isOn'] ?? false;

      if (!isOn || notifTime.isEmpty) continue;

      final normalizedNotifTime = _normalize(notifTime);

      // Check if current time matches scheduled time
      if (normalizedCurrent == normalizedNotifTime) {
        // Prevent double trigger in the same minute
        final todayKey = "${id}_${now.year}_${now.month}_${now.day}_${now.hour}_${now.minute}";
        if (!_triggeredToday.contains(todayKey)) {
          _triggeredToday.add(todayKey);
          
          if (context.mounted) {
            _showNotificationDialog(context, title);
          }
        }
      }
    }
  }

  static void _showNotificationDialog(BuildContext context, String title) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.phone_iphone, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 10),
                    const Text(
                      "Mobile Notification 📱",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      "now",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        "Dismiss",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        "View Details",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
