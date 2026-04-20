import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/auth_response.dart';
import '../models/booking_model.dart';
import '../models/service_model.dart';
import '../models/user_profile.dart';

class ApiService {
  static const Duration _requestTimeout = Duration(seconds: 45);

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    return 'http://10.0.2.2:8080';
  }

  static Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? contactNumber,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? profileImageUrl,
    int? experienceYears,
    String? skills,
    String? bio,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
      'role': role,
    };

    _putIfNotBlank(payload, 'contactNumber', contactNumber);
    _putIfNotBlank(payload, 'address', address);
    _putIfNotBlank(payload, 'city', city);
    _putIfNotBlank(payload, 'state', state);
    _putIfNotBlank(payload, 'pincode', pincode);
    _putIfNotBlank(payload, 'profileImageUrl', profileImageUrl);
    _putIfNotBlank(payload, 'skills', skills);
    _putIfNotBlank(payload, 'bio', bio);

    if (experienceYears != null) {
      payload['experienceYears'] = experienceYears;
    }

    final response = await _post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return AuthResponse.fromJson(jsonDecode(response.body));
    }
    throw Exception(_readError(response.body));
  }

  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      return AuthResponse.fromJson(jsonDecode(response.body));
    }
    throw Exception(_readError(response.body));
  }

  static Future<List<ServiceModel>> getServices() async {
    final response = await _get(Uri.parse('$baseUrl/services'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((item) => ServiceModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load services');
  }

  static Future<List<ServiceModel>> getProviderServices(int providerId) async {
    final response = await _get(
      Uri.parse('$baseUrl/services/provider/$providerId'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((item) => ServiceModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load provider services');
  }

  static Future<List<String>> getServiceTypes() async {
    final response = await _get(Uri.parse('$baseUrl/services/types'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    throw Exception('Failed to load service types');
  }

  static Future<void> createServiceByProvider({
    required int providerId,
    required String name,
    required double price,
    required String description,
  }) async {
    final response = await _post(
      Uri.parse('$baseUrl/services/provider'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'providerId': providerId,
        'name': name,
        'price': price,
        'description': description,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(_readError(response.body));
    }
  }

  static Future<void> updateServiceByProvider({
    required int serviceId,
    required int providerId,
    required String name,
    required double price,
    required String description,
  }) async {
    final response = await _put(
      Uri.parse('$baseUrl/services/provider/$serviceId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'providerId': providerId,
        'name': name,
        'price': price,
        'description': description,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(_readError(response.body));
    }
  }

  static Future<void> deleteServiceByProvider({
    required int serviceId,
    required int providerId,
  }) async {
    final response = await _delete(
      Uri.parse('$baseUrl/services/provider/$serviceId?providerId=$providerId'),
    );

    if (response.statusCode != 200) {
      throw Exception(_readError(response.body));
    }
  }

  static Future<UserProfile> getUserProfile(int userId) async {
    final response = await _get(Uri.parse('$baseUrl/users/$userId'));

    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load user profile');
  }

  static Future<UserProfile> updateProviderProfile({
    required int userId,
    required String contactNumber,
    required String address,
    required String city,
    String? state,
    String? pincode,
    String? profileImageUrl,
    int? experienceYears,
    String? skills,
    String? bio,
  }) async {
    final payload = <String, dynamic>{
      'contactNumber': contactNumber,
      'address': address,
      'city': city,
    };

    _putIfNotBlank(payload, 'state', state);
    _putIfNotBlank(payload, 'pincode', pincode);
    _putIfNotBlank(payload, 'profileImageUrl', profileImageUrl);
    _putIfNotBlank(payload, 'skills', skills);
    _putIfNotBlank(payload, 'bio', bio);

    if (experienceYears != null) {
      payload['experienceYears'] = experienceYears;
    }

    final response = await _put(
      Uri.parse('$baseUrl/users/$userId/provider-profile'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(response.body));
    }
    throw Exception(_readError(response.body));
  }

  static Future<void> createBooking({
    required int userId,
    required int serviceId,
    required DateTime date,
  }) async {
    final response = await _post(
      Uri.parse('$baseUrl/bookings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'serviceId': serviceId,
        'date': _formatDate(date),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(_readError(response.body));
    }
  }

  static Future<List<BookingModel>> getBookingsByUserId(int userId) async {
    final response = await _get(Uri.parse('$baseUrl/bookings/$userId'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((item) => BookingModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load bookings');
  }

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static Future<http.Response> _get(
    Uri uri, {
    Map<String, String>? headers,
  }) {
    return _send(() => http.get(uri, headers: headers));
  }

  static Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _send(() => http.post(uri, headers: headers, body: body));
  }

  static Future<http.Response> _put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _send(() => http.put(uri, headers: headers, body: body));
  }

  static Future<http.Response> _delete(
    Uri uri, {
    Map<String, String>? headers,
  }) {
    return _send(() => http.delete(uri, headers: headers));
  }

  static Future<http.Response> _send(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception(
        'Server is taking longer than expected. It may be waking up after inactivity. Please try again in a few seconds.',
      );
    } on http.ClientException {
      throw Exception(
        'Unable to reach server right now. It may be waking up after inactivity. Please try again shortly.',
      );
    }
  }

  static String _readError(String body) {
    try {
      final parsed = jsonDecode(body) as Map<String, dynamic>;
      return parsed['message'] as String? ?? 'Request failed';
    } catch (_) {
      return 'Request failed';
    }
  }

  static void _putIfNotBlank(
    Map<String, dynamic> payload,
    String key,
    String? value,
  ) {
    if (value == null) {
      return;
    }

    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      payload[key] = trimmed;
    }
  }
}