import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class UserService {
  static Future<bool> saveProfile(Map<String, dynamic> profileData) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/user/profile'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(profileData),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("Error saving profile: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/user/profile/$userId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print("Error fetching profile: $e");
      return null;
    }
  }

  static Future<bool> addCustomNotification(String userId, String title, String time, {String repeat = "None"}) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/setNotification'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": userId,
          "title": title,
          "time": time,
          "isOn": true,
          "repeat": repeat
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error adding custom notification: $e");
      return false;
    }
  }

  static Future<bool> updateCustomNotification(String userId, String notificationId, {String? title, String? time, bool? isOn, String? repeat}) async {
    try {
      final Map<String, dynamic> body = {
        "userId": userId,
      };
      if (title != null) body["title"] = title;
      if (time != null) body["time"] = time;
      if (isOn != null) body["isOn"] = isOn;
      if (repeat != null) body["repeat"] = repeat;

      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}/setNotification/$notificationId'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error updating custom notification: $e");
      return false;
    }
  }

  static Future<bool> deleteCustomNotification(String userId, String notificationId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiService.baseUrl}/setNotification/$notificationId'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": userId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error deleting custom notification: $e");
      return false;
    }
  }

  static Future<bool> createNotificationLog(String userId, String message, {String type = "reminder"}) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/notifications'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": userId,
          "message": message,
          "type": type,
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      print("Error creating notification log: $e");
      return false;
    }
  }

  static Future<bool> deleteHistory(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiService.baseUrl}/history?userId=$userId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error deleting history: $e");
      return false;
    }
  }
}
