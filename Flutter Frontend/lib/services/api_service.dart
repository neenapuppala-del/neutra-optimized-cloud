import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String get baseUrl {
    return "https://neutra-optimized-cloud.onrender.com";
  }

  static Future<Map<String, dynamic>?> detectFood(
      List<List<int>> multipleImageBytes,
      List<String> filenames) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/phase1/detect'),
      );

      for (int i = 0; i < multipleImageBytes.length; i++) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'files',
            multipleImageBytes[i],
            filename: filenames[i],
          ),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Detect Error: ${response.statusCode}");
        print(response.body);
        return null;
      }
    } catch (e) {
      print("Exception detecting food: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> calculateNutrition(
      Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final userId = prefs.getString('userId');

      if (userId != null) {
        payload['userId'] = userId;
      }

      var response = await http.post(
        Uri.parse('$baseUrl/api/phase2/nutrition'),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Nutrition Error: ${response.statusCode}");
        print(response.body);
        return null;
      }
    } catch (e) {
      print("Exception calculating nutrition: $e");
      return null;
    }
  }

  static Future<bool> logMeal(
    String dishName,
    int healthScore,
    Map<String, dynamic> nutrients,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final userId = prefs.getString('userId');

      if (userId == null) return false;

      var response = await http.post(
        Uri.parse('$baseUrl/analytics/log'),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "userId": userId,
          "dishName": dishName,
          "healthScore": healthScore,
          "nutrients": nutrients,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Exception logging meal: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getDailyStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final userId = prefs.getString('userId');

      if (userId == null) return null;

      final offset = DateTime.now().timeZoneOffset.inMinutes;

      var response = await http.get(
        Uri.parse(
          '$baseUrl/analytics/daily?userId=$userId&timezoneOffset=$offset',
        ),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      return null;
    } catch (e) {
      print("Exception getting daily stats: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getWeeklyAnalytics() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final userId = prefs.getString('userId');

      if (userId == null) return null;

      final offset = DateTime.now().timeZoneOffset.inMinutes;

      var response = await http.get(
        Uri.parse(
          '$baseUrl/analytics/weekly?userId=$userId&timezoneOffset=$offset',
        ),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      return null;
    } catch (e) {
      print("Exception getting weekly analytics: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getDailyReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final userId = prefs.getString('userId');

      if (userId == null) return null;

      final offset = DateTime.now().timeZoneOffset.inMinutes;

      var response = await http.get(
        Uri.parse(
          '$baseUrl/analytics/daily-review?userId=$userId&timezoneOffset=$offset',
        ),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      return null;
    } catch (e) {
      print("Exception getting daily review: $e");
      return null;
    }
  }

  static Future<List<dynamic>?> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final userId = prefs.getString('userId');

      if (userId == null) return null;

      var response = await http.get(
        Uri.parse('$baseUrl/history?userId=$userId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      return null;
    } catch (e) {
      print("Exception getting history: $e");
      return null;
    }
  }
}