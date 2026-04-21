import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_response.dart';
import '../models/booking_model.dart';
import '../models/provider_earnings_model.dart';
import '../models/review_model.dart';
import '../models/service_model.dart';
import '../models/user_profile.dart';

enum ApiServerMode {
  deployed,
  local,
}

class ApiService {
  static const Duration _requestTimeout = Duration(seconds: 45);
  static const String _deployedBaseUrl =
      'https://servico-app-server.onrender.com';
  static const String _defaultLocalBaseUrl = 'http://10.0.2.2:8080';
  static const String _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _configuredLocalBaseUrl =
      String.fromEnvironment('LOCAL_API_BASE_URL');
  static const String _configuredServerMode =
      String.fromEnvironment('API_SERVER_MODE');
  static const String _serverModePreferenceKey = 'apiServerMode';

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _normalizeBaseUrl(_configuredBaseUrl);
    }
    return _normalizeBaseUrl(_deployedBaseUrl);
  }

  static Future<ApiServerMode> getServerMode() async {
    final configured = _configuredServerMode.trim().toLowerCase();
    if (configured == 'local') {
      return ApiServerMode.local;
    }
    if (configured == 'deployed') {
      return ApiServerMode.deployed;
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_serverModePreferenceKey)?.trim().toLowerCase();
    if (stored == 'local') {
      return ApiServerMode.local;
    }
    return ApiServerMode.deployed;
  }

  static Future<void> setServerMode(ApiServerMode mode) async {
    if (_configuredServerMode.isNotEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverModePreferenceKey, mode.name);
  }

  static Future<bool> hasStoredServerModeChoice() async {
    if (_configuredBaseUrl.isNotEmpty || _configuredServerMode.isNotEmpty) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_serverModePreferenceKey)?.trim().toLowerCase();
    return stored == 'local' || stored == 'deployed';
  }

  static bool get isServerModeRuntimeConfigurable {
    return _configuredBaseUrl.isEmpty && _configuredServerMode.isEmpty;
  }

  static Future<String> getActiveBaseUrlForDisplay() {
    return _activeBaseUrl();
  }

  static Future<String> _activeBaseUrl() async {
    if (_configuredBaseUrl.isNotEmpty) {
      return _normalizeBaseUrl(_configuredBaseUrl);
    }

    final local = _normalizeBaseUrl(
      _configuredLocalBaseUrl.isNotEmpty
          ? _configuredLocalBaseUrl
          : _defaultLocalBaseUrl,
    );
    final deployed = _normalizeBaseUrl(_deployedBaseUrl);
    final mode = await getServerMode();
    return mode == ApiServerMode.local ? local : deployed;
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

  static Future<List<ServiceModel>> getServices({
    double? minPrice,
    double? maxPrice,
    double? minRating,
    double? maxDistanceKm,
    double? userLatitude,
    double? userLongitude,
    bool? onlyAvailable,
    DateTime? availableDate,
  }) async {
    final queryParameters = <String, String>{};

    _putQueryNumber(queryParameters, 'minPrice', minPrice);
    _putQueryNumber(queryParameters, 'maxPrice', maxPrice);
    _putQueryNumber(queryParameters, 'minRating', minRating);
    _putQueryNumber(queryParameters, 'maxDistanceKm', maxDistanceKm);
    _putQueryNumber(queryParameters, 'userLatitude', userLatitude);
    _putQueryNumber(queryParameters, 'userLongitude', userLongitude);

    if (onlyAvailable != null) {
      queryParameters['onlyAvailable'] = onlyAvailable.toString();
    }

    if (availableDate != null) {
      queryParameters['availableDate'] = _formatDate(availableDate);
    }

    final uri = Uri.parse('$baseUrl/services').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    final response = await _get(uri);

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

  static Future<UserProfile> updateUserProfile({
    required int userId,
    required String name,
    String? contactNumber,
    String? address,
    String? city,
    String? state,
    String? pincode,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
    };

    payload['contactNumber'] = contactNumber?.trim();
    payload['address'] = address?.trim();
    payload['city'] = city?.trim();
    payload['state'] = state?.trim();
    payload['pincode'] = pincode?.trim();

    final response = await _put(
      Uri.parse('$baseUrl/users/$userId/profile'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(response.body));
    }
    throw Exception(_readError(response.body));
  }

  static Future<UserProfile> updateProviderProfile({
    required int userId,
    required String contactNumber,
    required String address,
    required String city,
    String? state,
    String? pincode,
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

  static Future<UserProfile> updateProviderLocation({
    required int userId,
    required bool liveLocationSharingEnabled,
    double? latitude,
    double? longitude,
  }) async {
    final payload = <String, dynamic>{
      'liveLocationSharingEnabled': liveLocationSharingEnabled,
    };

    if (latitude != null && longitude != null) {
      payload['latitude'] = latitude;
      payload['longitude'] = longitude;
    }

    final response = await _put(
      Uri.parse('$baseUrl/users/$userId/provider-location'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(response.body));
    }
    throw Exception(_readError(response.body));
  }

  static Future<UserProfile> uploadProfileImage({
    required int userId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final mimeType = lookupMimeType(
      fileName,
      headerBytes: fileBytes.take(12).toList(),
    );

    MediaType? mediaType;
    if (mimeType != null) {
      final segments = mimeType.split('/');
      if (segments.length == 2) {
        mediaType = MediaType(segments[0], segments[1]);
      }
    }

    final endpoint = Uri.parse('$baseUrl/users/$userId/profile-image');
    final response = await _sendMultipart(
      endpoint,
      (uri) {
        final request = http.MultipartRequest('POST', uri);
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: fileName,
            contentType: mediaType,
          ),
        );
        return request;
      },
    );

    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(response.body));
    }

    throw Exception(_readError(response.body));
  }

  static Future<UserProfile> removeProfileImage({
    required int userId,
  }) async {
    final response = await _delete(Uri.parse('$baseUrl/users/$userId/profile-image'));

    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(response.body));
    }

    throw Exception(_readError(response.body));
  }

  static Future<BookingModel> createBooking({
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

    if (response.statusCode == 200) {
      return BookingModel.fromJson(jsonDecode(response.body));
    }

    throw Exception(_readError(response.body));
  }

  static Future<List<BookingModel>> getBookingsByUserId(
    int userId, {
    int? providerId,
  }) async {
    final uri = Uri.parse('$baseUrl/bookings/$userId').replace(
      queryParameters: providerId == null
          ? null
          : {
              'providerId': providerId.toString(),
            },
    );

    final response = await _get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((item) => BookingModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load bookings');
  }

  static Future<List<BookingModel>> getProviderBookings(int providerId) async {
    final response = await _get(Uri.parse('$baseUrl/bookings/provider/$providerId'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((item) => BookingModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load provider bookings');
  }

  static Future<BookingModel> updateBookingStatusByProvider({
    required int bookingId,
    required int providerId,
    required String status,
    String? trackingNote,
  }) async {
    final payload = <String, dynamic>{
      'providerId': providerId,
      'status': status,
    };

    _putIfNotBlank(payload, 'trackingNote', trackingNote);

    final response = await _put(
      Uri.parse('$baseUrl/bookings/$bookingId/provider-status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return BookingModel.fromJson(jsonDecode(response.body));
    }
    throw Exception(_readError(response.body));
  }

  static Future<ReviewModel> createReview({
    required int bookingId,
    required int userId,
    required int rating,
    String? comment,
  }) async {
    final payload = <String, dynamic>{
      'bookingId': bookingId,
      'userId': userId,
      'rating': rating,
    };
    _putIfNotBlank(payload, 'comment', comment);

    final response = await _post(
      Uri.parse('$baseUrl/reviews'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return ReviewModel.fromJson(jsonDecode(response.body));
    }
    throw Exception(_readError(response.body));
  }

  static Future<List<ReviewModel>> getProviderReviews(int providerId) async {
    final response = await _get(Uri.parse('$baseUrl/reviews/provider/$providerId'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((item) => ReviewModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load provider reviews');
  }

  static Future<ReviewModel> replyToReview({
    required int reviewId,
    required int providerId,
    required String response,
  }) async {
    final apiResponse = await _put(
      Uri.parse('$baseUrl/reviews/$reviewId/reply'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'providerId': providerId,
        'response': response,
      }),
    );

    if (apiResponse.statusCode == 200) {
      return ReviewModel.fromJson(jsonDecode(apiResponse.body));
    }
    throw Exception(_readError(apiResponse.body));
  }

  static Future<ProviderEarningsModel> getProviderEarnings({
    required int providerId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final query = <String, String>{};
    if (fromDate != null) {
      query['fromDate'] = _formatDate(fromDate);
    }
    if (toDate != null) {
      query['toDate'] = _formatDate(toDate);
    }

    final uri = Uri.parse('$baseUrl/providers/$providerId/earnings').replace(
      queryParameters: query.isEmpty ? null : query,
    );

    final response = await _get(uri);

    if (response.statusCode == 200) {
      return ProviderEarningsModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw Exception(_readError(response.body));
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
    return _send(
      uri,
      (requestUri) => http.get(requestUri, headers: headers),
    );
  }

  static Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _send(
      uri,
      (requestUri) => http.post(requestUri, headers: headers, body: body),
    );
  }

  static Future<http.Response> _put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _send(
      uri,
      (requestUri) => http.put(requestUri, headers: headers, body: body),
    );
  }

  static Future<http.Response> _delete(
    Uri uri, {
    Map<String, String>? headers,
  }) {
    return _send(
      uri,
      (requestUri) => http.delete(requestUri, headers: headers),
    );
  }

  static Future<http.Response> _send(
    Uri initialUri,
    Future<http.Response> Function(Uri requestUri) request,
  ) async {
    final activeBaseUrl = await _activeBaseUrl();
    final requestUri = _withBaseUrl(initialUri, activeBaseUrl);

    try {
      return await request(requestUri).timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception(
        'Request timed out while contacting the ${_describeBackend(activeBaseUrl)} backend ($activeBaseUrl).',
      );
    } on http.ClientException {
      throw Exception(
        'Unable to reach the ${_describeBackend(activeBaseUrl)} backend ($activeBaseUrl).',
      );
    }
  }

  static Future<http.Response> _sendMultipart(
    Uri initialUri,
    http.MultipartRequest Function(Uri requestUri) requestBuilder,
  ) async {
    final activeBaseUrl = await _activeBaseUrl();
    final requestUri = _withBaseUrl(initialUri, activeBaseUrl);

    try {
      final request = requestBuilder(requestUri);
      final streamed = await request.send().timeout(_requestTimeout);
      return http.Response.fromStream(streamed);
    } on TimeoutException {
      throw Exception(
        'Upload timed out while contacting the ${_describeBackend(activeBaseUrl)} backend ($activeBaseUrl).',
      );
    } on http.ClientException {
      throw Exception(
        'Unable to upload to the ${_describeBackend(activeBaseUrl)} backend ($activeBaseUrl).',
      );
    }
  }

  static Uri _withBaseUrl(Uri originalUri, String baseUrl) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      path: originalUri.path,
      query: originalUri.hasQuery ? originalUri.query : null,
    );
  }

  static String _normalizeBaseUrl(String input) {
    final trimmed = input.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static String _describeBackend(String baseUrl) {
    final normalized = _normalizeBaseUrl(baseUrl);
    final normalizedLocal = _normalizeBaseUrl(
      _configuredLocalBaseUrl.isNotEmpty
          ? _configuredLocalBaseUrl
          : _defaultLocalBaseUrl,
    );
    final normalizedDeployed = _normalizeBaseUrl(_deployedBaseUrl);

    if (normalized == normalizedLocal) {
      return 'local';
    }
    if (normalized == normalizedDeployed) {
      return 'deployed';
    }
    return 'configured';
  }

  static String _readError(String body) {
    try {
      final parsed = jsonDecode(body);

      if (parsed is Map<String, dynamic>) {
        final message = [
          parsed['message'],
          parsed['error'],
          parsed['detail'],
          parsed['title'],
        ]
            .whereType<String>()
            .map((value) => value.trim())
            .firstWhere(
              (value) => value.isNotEmpty,
              orElse: () => '',
            );

        if (message.isNotEmpty) {
          final errorId = (parsed['errorId'] as String?)?.trim();
          if (errorId != null && errorId.isNotEmpty) {
            return '$message (Ref: $errorId)';
          }
          return message;
        }
      }

      if (parsed is String && parsed.trim().isNotEmpty) {
        return parsed.trim();
      }
    } catch (_) {
      // Fall back to raw response text below.
    }

    final raw = body.trim();
    if (raw.isNotEmpty) {
      return raw;
    }

    return 'Request failed';
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

  static void _putQueryNumber(
    Map<String, String> query,
    String key,
    double? value,
  ) {
    if (value == null) {
      return;
    }

    query[key] = value.toString();
  }
}
