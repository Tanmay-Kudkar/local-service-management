import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/service_model.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/server_warmup_loading.dart';
import '../widgets/server_selector_sheet.dart';
import 'auth_screen.dart';
import 'booking_screen.dart';
import 'my_bookings_screen.dart';

class ServiceListScreen extends StatefulWidget {
  final int userId;
  final String userName;

  const ServiceListScreen({
    super.key,
    required this.userId,
    this.userName = '',
  });

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  bool _isLoading = true;
  bool _showWarmupHint = false;
  List<ServiceModel> _services = [];
  bool _showContent = false;
  Timer? _warmupHintTimer;
  bool _isEditProfileDialogOpen = false;
  String _displayName = '';
  UserProfile? _userProfile;
  int _loadRequestVersion = 0;
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  final _minRatingController = TextEditingController();
  final _maxDistanceController = TextEditingController();
  bool _onlyAvailable = false;
  DateTime? _availableDate;
  double? _userLatitude;
  double? _userLongitude;
  String? _userLocationLabel;
  bool _isFetchingLocation = false;
  ApiServerMode _serverMode = ApiServerMode.deployed;
  String? _activeServerUrl;

  @override
  void initState() {
    super.initState();
    _minPriceController.addListener(_onFilterTextChanged);
    _maxPriceController.addListener(_onFilterTextChanged);
    _minRatingController.addListener(_onFilterTextChanged);
    _maxDistanceController.addListener(_onFilterTextChanged);
    _displayName = widget.userName.trim();
    _loadServerModeConfig();
    _loadServices();
    _loadUserProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _showContent = true;
      });
    });
  }

  @override
  void dispose() {
    _warmupHintTimer?.cancel();
    _minPriceController.removeListener(_onFilterTextChanged);
    _maxPriceController.removeListener(_onFilterTextChanged);
    _minRatingController.removeListener(_onFilterTextChanged);
    _maxDistanceController.removeListener(_onFilterTextChanged);
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _minRatingController.dispose();
    _maxDistanceController.dispose();
    super.dispose();
  }

  void _onFilterTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadServices() async {
    final requestVersion = ++_loadRequestVersion;
    setState(() {
      _isLoading = true;
      _showWarmupHint = false;
    });

    _warmupHintTimer?.cancel();
    _warmupHintTimer = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      if (_isLoading && requestVersion == _loadRequestVersion) {
        setState(() {
          _showWarmupHint = true;
        });
      }
    });

    try {
      final minPrice = _parseDoubleOrNull(_minPriceController.text);
      final maxPrice = _parseDoubleOrNull(_maxPriceController.text);
      final minRating = _parseDoubleOrNull(_minRatingController.text);
      final maxDistance = _parseDoubleOrNull(_maxDistanceController.text);

      final services = await ApiService.getServices(
        minPrice: minPrice,
        maxPrice: maxPrice,
        minRating: minRating,
        maxDistanceKm: maxDistance,
        userLatitude: _userLatitude,
        userLongitude: _userLongitude,
        onlyAvailable: _onlyAvailable,
        availableDate: _onlyAvailable ? (_availableDate ?? DateTime.now()) : null,
      );
      if (!mounted) return;
      setState(() {
        _services = services;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isEmpty ? 'Failed to load services' : message,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  double? _parseDoubleOrNull(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.tryParse(trimmed);
  }

  Future<void> _applyFilters() async {
    final minRating = _parseDoubleOrNull(_minRatingController.text);
    if (minRating != null && (minRating < 0 || minRating > 5)) {
      _showMessage('Min rating should be between 0 and 5.');
      return;
    }

    final minPrice = _parseDoubleOrNull(_minPriceController.text);
    final maxPrice = _parseDoubleOrNull(_maxPriceController.text);
    if (minPrice != null && maxPrice != null && minPrice > maxPrice) {
      _showMessage('Min price cannot be greater than max price.');
      return;
    }

    await _loadServices();
  }

  Future<void> _clearFilters() async {
    _minPriceController.clear();
    _maxPriceController.clear();
    _minRatingController.clear();
    _maxDistanceController.clear();
    setState(() {
      _onlyAvailable = false;
      _availableDate = null;
      _userLatitude = null;
      _userLongitude = null;
      _userLocationLabel = null;
    });
    await _loadServices();
  }

  Future<void> _loadServerModeConfig() async {
    final mode = await ApiService.getServerMode();
    final baseUrl = await ApiService.getActiveBaseUrlForDisplay();
    if (!mounted) return;
    setState(() {
      _serverMode = mode;
      _activeServerUrl = baseUrl;
    });
  }

  Future<void> _changeServerMode() async {
    if (!ApiService.isServerModeRuntimeConfigurable) {
      _showMessage('Server mode is locked by build configuration.');
      return;
    }

    final selectedMode = await showServerModeSelectorSheet(context, _serverMode);
    if (selectedMode == null || selectedMode == _serverMode) {
      return;
    }

    await ApiService.setServerMode(selectedMode);
    if (!mounted) return;

    setState(() {
      _serverMode = selectedMode;
    });

    await _loadServerModeConfig();
    _showMessage('Server set to ${serverModeLabel(selectedMode)}.');
    await _loadServices();
  }

  Future<void> _pickAvailabilityDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _availableDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _availableDate = pickedDate;
      _onlyAvailable = true;
    });
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage('Please enable location services on your device.');
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      _showMessage('Location permission is permanently denied. Open app settings to allow it.');
      await Geolocator.openAppSettings();
      return false;
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showMessage('Location permission is required for distance filtering.');
      return false;
    }

    return true;
  }

  Future<void> _useCurrentLocation() async {
    if (_isFetchingLocation) {
      return;
    }

    final allowed = await _ensureLocationPermission();
    if (!allowed) {
      return;
    }

    setState(() {
      _isFetchingLocation = true;
    });

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _userLatitude = position.latitude;
        _userLongitude = position.longitude;
      });
      await _resolveUserLocationLabel(position.latitude, position.longitude);
      _showMessage('Using current location for distance filter.');
    } catch (_) {
      _showMessage('Unable to fetch current location.');
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  Future<void> _resolveUserLocationLabel(double latitude, double longitude) async {
    String label = 'Current location';

    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = <String?>[
          place.subLocality,
          place.locality,
          place.administrativeArea,
        ]
            .map((part) => (part ?? '').trim())
            .where((part) => part.isNotEmpty)
            .toList();

        if (parts.isNotEmpty) {
          label = parts.take(2).join(', ');
        }
      }
    } catch (_) {
      // Keep fallback label when reverse geocoding fails.
    }

    if (!mounted) return;
    setState(() {
      _userLocationLabel = label;
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await ApiService.getUserProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        _displayName = profile.name;
        _userProfile = profile;
      });
    } catch (_) {
      // Keep existing display name if profile fetch fails.
    }
  }

  Future<void> _refreshHomeData() async {
    await Future.wait([
      _loadServices(),
      _loadUserProfile(),
    ]);
  }

  Future<void> _openMyBookings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyBookingsScreen(userId: widget.userId),
      ),
    );

    if (!mounted) {
      return;
    }

    await _refreshHomeData();
  }

  Future<void> _openEditProfileDialog() async {
    if (_isEditProfileDialogOpen) {
      return;
    }

    _isEditProfileDialogOpen = true;
    final profile = _userProfile;
    final nameController = TextEditingController(
      text: profile?.name ?? _displayName,
    );
    final contactController = TextEditingController(
      text: profile?.contactNumber ?? '',
    );
    final addressController = TextEditingController(
      text: profile?.address ?? '',
    );
    final cityController = TextEditingController(
      text: profile?.city ?? '',
    );
    final stateController = TextEditingController(
      text: profile?.state ?? '',
    );
    final pincodeController = TextEditingController(
      text: profile?.pincode ?? '',
    );

    bool isSaving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Edit Profile'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        enabled: !isSaving,
                        decoration: const InputDecoration(
                          labelText: 'Name *',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: contactController,
                        enabled: !isSaving,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Contact Number',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: addressController,
                        enabled: !isSaving,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          prefixIcon: Icon(Icons.home_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: cityController,
                        enabled: !isSaving,
                        decoration: const InputDecoration(
                          labelText: 'City',
                          prefixIcon: Icon(Icons.location_city_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: stateController,
                        enabled: !isSaving,
                        decoration: const InputDecoration(
                          labelText: 'State',
                          prefixIcon: Icon(Icons.map_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: pincodeController,
                        enabled: !isSaving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Pincode',
                          prefixIcon: Icon(Icons.pin_drop_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final navigator = Navigator.of(dialogContext);
                            final name = nameController.text.trim();
                            final contact = contactController.text.trim();
                            final address = addressController.text.trim();
                            final pincode = pincodeController.text.trim();

                            if (name.isEmpty) {
                              _showMessage('Name is required.');
                              return;
                            }

                            if (contact.isNotEmpty &&
                                (contact.length != 10 ||
                                    !RegExp(r'^[6-9][0-9]{9}').hasMatch(contact))) {
                              _showMessage('Enter a valid 10-digit Indian mobile number.');
                              return;
                            }

                            if (address.isNotEmpty && address.length < 10) {
                              _showMessage('Address must be at least 10 characters.');
                              return;
                            }

                            if (pincode.isNotEmpty &&
                                (pincode.length != 6 ||
                                    !RegExp(r'^[1-9][0-9]{5}').hasMatch(pincode))) {
                              _showMessage('Enter a valid 6-digit pincode.');
                              return;
                            }

                            setDialogState(() {
                              isSaving = true;
                            });

                            try {
                              final updatedProfile = await ApiService.updateUserProfile(
                                userId: widget.userId,
                                name: name,
                                contactNumber: contact,
                                address: address,
                                city: cityController.text.trim(),
                                state: stateController.text.trim(),
                                pincode: pincode,
                              );

                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('userName', updatedProfile.name);

                              if (!mounted) {
                                return;
                              }

                              setState(() {
                                _displayName = updatedProfile.name;
                                _userProfile = updatedProfile;
                              });

                              if (navigator.mounted) {
                                navigator.pop();
                              }

                              _showMessage('Profile updated successfully.');
                            } catch (e) {
                              if (navigator.mounted) {
                                setDialogState(() {
                                  isSaving = false;
                                });
                              }
                              _showMessage(
                                e.toString().replaceFirst('Exception: ', ''),
                              );
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      _isEditProfileDialogOpen = false;
      nameController.dispose();
      contactController.dispose();
      addressController.dispose();
      cityController.dispose();
      stateController.dispose();
      pincodeController.dispose();
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('userName');
    await prefs.remove('userRole');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  void _showProviderDetails(ServiceModel service) {
    if (service.providerName == null || service.providerName!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Provider profile is not available for this service yet.'),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ProviderDetailsSheet(service: service);
      },
    );
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  int _activeFilterCount() {
    var count = 0;

    if (_parseDoubleOrNull(_minPriceController.text) != null) {
      count++;
    }
    if (_parseDoubleOrNull(_maxPriceController.text) != null) {
      count++;
    }
    if (_parseDoubleOrNull(_minRatingController.text) != null) {
      count++;
    }
    if (_parseDoubleOrNull(_maxDistanceController.text) != null) {
      count++;
    }
    if (_onlyAvailable) {
      count++;
    }
    if (_availableDate != null) {
      count++;
    }
    if (_userLatitude != null && _userLongitude != null) {
      count++;
    }

    return count;
  }

  @override
  Widget build(BuildContext context) {
    final hasPreviousRoute = Navigator.of(context).canPop();

    return PopScope(
      canPop: hasPreviousRoute,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        if (hasPreviousRoute) {
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
      },
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: _refreshHomeData,
              child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  toolbarHeight: 68,
                  pinned: true,
                  floating: false,
                  automaticallyImplyLeading: false,
                  centerTitle: true,
                  surfaceTintColor: Colors.transparent,
                  backgroundColor: AppTheme.brand,
                  title: const Text(
                    'Customer Home',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 2, 8),
                      child: Tooltip(
                        message: 'My Bookings',
                        child: IconButton(
                          onPressed: _openMyBookings,
                          icon: const Icon(Icons.receipt_long_rounded),
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 2, 8),
                      child: Tooltip(
                        message: 'Edit Profile',
                        child: IconButton(
                          onPressed: _openEditProfileDialog,
                          icon: const Icon(Icons.manage_accounts_outlined),
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                      child: Tooltip(
                        message: _activeServerUrl == null
                            ? 'Server: ${serverModeLabel(_serverMode)}'
                            : 'Server: ${serverModeLabel(_serverMode)}\n$_activeServerUrl',
                        child: IconButton(
                          onPressed: _changeServerMode,
                          icon: const Icon(Icons.cloud_outlined),
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 12, 8),
                      child: Tooltip(
                        message: 'Logout',
                        child: IconButton(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout_rounded),
                          style: IconButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppTheme.brand,
                            Color(0xFF165651),
                            Color(0xFF113F3B),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0A2F2B).withValues(alpha: 0.24),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 360;

                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                              compact ? 14 : 18,
                              compact ? 14 : 18,
                              compact ? 14 : 18,
                              compact ? 14 : 16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        'Trusted Local Services',
                                        style: TextStyle(
                                          color: Color(0xFFE8FAF6),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.home_repair_service_rounded,
                                      color: Color(0xFFE8FAF6),
                                      size: 18,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Hello, ${_displayName.isEmpty ? 'User' : _displayName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: compact ? 20 : 22,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Book trusted local experts in seconds.',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Color(0xFFE7F8F4),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Available Services',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: compact ? 28 : 31,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _HeroPill(
                                      icon: Icons.inventory_2_outlined,
                                      text: _isLoading
                                          ? 'Syncing listings'
                                          : '${_services.length} ready now',
                                    ),
                                    _HeroPill(
                                      icon: Icons.my_location_rounded,
                                      text: _userLatitude == null
                                          ? 'Location off'
                                          : 'Location on',
                                    ),
                                    _HeroPill(
                                      icon: Icons.filter_alt_outlined,
                                      text: '${_activeFilterCount()} filters',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.brand.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                color: AppTheme.brand,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'My Bookings',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'View all your bookings and submit reviews.',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: _openMyBookings,
                              child: const Text('View All'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Text(
                      _isLoading
                          ? (_showWarmupHint
                              ? 'Waking up server and loading services...'
                              : 'Loading services...')
                          : '${_services.length} services ready to book',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 360;
                            final activeFilters = _activeFilterCount();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F8F6),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppTheme.brand.withValues(alpha: 0.15),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.tune_rounded,
                                        color: AppTheme.brand,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Find Faster',
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: activeFilters > 0
                                              ? AppTheme.brand.withValues(alpha: 0.14)
                                              : const Color(0xFFE9EEEE),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          activeFilters > 0
                                              ? '$activeFilters active'
                                              : 'No filters',
                                          style: TextStyle(
                                            color: activeFilters > 0
                                                ? AppTheme.brand
                                                : const Color(0xFF5F7270),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Filter by budget, rating, distance, date, and location.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Quick Inputs',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _minPriceController,
                                        keyboardType: const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                        decoration: const InputDecoration(
                                          labelText: 'Min price',
                                          prefixIcon: Icon(Icons.price_change_outlined),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _maxPriceController,
                                        keyboardType: const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                        decoration: const InputDecoration(
                                          labelText: 'Max price',
                                          prefixIcon: Icon(Icons.payments_outlined),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _minRatingController,
                                        keyboardType: const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                        decoration: const InputDecoration(
                                          labelText: 'Min rating',
                                          prefixIcon: Icon(Icons.star_border_rounded),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _maxDistanceController,
                                        keyboardType: const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                        decoration: const InputDecoration(
                                          labelText: 'Max km',
                                          prefixIcon: Icon(Icons.near_me_outlined),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  value: _onlyAvailable,
                                  onChanged: (value) {
                                    setState(() {
                                      _onlyAvailable = value;
                                    });
                                  },
                                  title: const Text('Only available services'),
                                  subtitle: Text(
                                    _availableDate == null
                                        ? 'Select a date to check availability'
                                        : 'Date: ${_formatDate(_availableDate!)}',
                                  ),
                                ),
                                if (_availableDate != null ||
                                    (_userLatitude != null && _userLongitude != null)) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (_availableDate != null)
                                        _FilterStatusChip(
                                          icon: Icons.event_available_rounded,
                                          text: _formatDate(_availableDate!),
                                        ),
                                      if (_userLatitude != null && _userLongitude != null)
                                        _FilterStatusChip(
                                          icon: Icons.my_location_rounded,
                                          text: _userLocationLabel ?? 'Current location',
                                        ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _pickAvailabilityDate,
                                        icon: const Icon(Icons.event_available_rounded),
                                        label: const Text('Set Date'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _isFetchingLocation ? null : _useCurrentLocation,
                                        icon: _isFetchingLocation
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              )
                                            : const Icon(Icons.my_location_rounded),
                                        label: Text(
                                          _isFetchingLocation
                                              ? 'Locating...'
                                              : (_userLatitude == null
                                                  ? 'Use Location'
                                                  : 'Location Set'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (compact)
                                  Column(
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _applyFilters,
                                          icon: const Icon(Icons.filter_alt_rounded),
                                          label: const Text('Apply Filters'),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: _clearFilters,
                                          icon: const Icon(Icons.filter_alt_off_rounded),
                                          label: const Text('Clear'),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _applyFilters,
                                          icon: const Icon(Icons.filter_alt_rounded),
                                          label: const Text('Apply Filters'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      OutlinedButton.icon(
                                        onPressed: _clearFilters,
                                        icon: const Icon(Icons.filter_alt_off_rounded),
                                        label: const Text('Clear'),
                                      ),
                                    ],
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isLoading)
                  ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: ServerWarmupBanner(
                          showWarmupMessage: _showWarmupHint,
                          title: 'Loading services',
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.builder(
                        itemCount: 5,
                        itemBuilder: (context, index) => const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: ServiceSkeletonCard(),
                        ),
                      ),
                    ),
                  ]
                else if (_services.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(onRefresh: _loadServices),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverList.builder(
                      itemCount: _services.length,
                      itemBuilder: (context, index) {
                        final service = _services[index];
                        final delay = ((index * 80).clamp(0, 400)).toInt();

                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: _showContent ? 1 : 0),
                          duration: Duration(milliseconds: 260 + delay),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, (1 - value) * 12),
                                child: child,
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ServiceCard(
                              service: service,
                              onBook: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BookingScreen(
                                      userId: widget.userId,
                                      service: service,
                                    ),
                                  ),
                                );

                                if (!mounted) {
                                  return;
                                }

                                await _refreshHomeData();
                              },
                              onProviderDetails: () {
                                _showProviderDetails(service);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceModel service;
  final VoidCallback onBook;
  final VoidCallback onProviderDetails;

  const _ServiceCard({
    required this.service,
    required this.onBook,
    required this.onProviderDetails,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _serviceMeta(service.name);
    final displayHint = (service.description != null && service.description!.trim().isNotEmpty)
        ? service.description!
        : meta.hint;
    final providerName = service.providerName?.trim() ?? '';
    final providerImage = _providerImageFromService(service);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: service.available ? onBook : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 430;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'service-icon-${service.id}',
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: meta.color.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(meta.icon, color: meta.color),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'From Rs ${service.price.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: meta.color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    meta.badge,
                                    style: TextStyle(
                                      color: meta.color,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                if (service.providerCity != null && service.providerCity!.trim().isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0F4F7),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      service.providerCity!,
                                      style: const TextStyle(
                                        color: Color(0xFF335066),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    displayHint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (providerName.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF6F3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: const Color(0xFFD4ECE8),
                            backgroundImage: providerImage,
                            child: providerImage == null
                                ? const Icon(
                                    Icons.person_rounded,
                                    size: 15,
                                    color: AppTheme.brand,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              service.providerVerified
                                  ? '$providerName (Verified)'
                                  : providerName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF0E6F67),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (service.providerExperienceYears != null ||
                      service.providerDistanceKm != null ||
                      !service.available) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (service.providerExperienceYears != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4F7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${service.providerExperienceYears} yrs exp',
                              style: const TextStyle(
                                color: Color(0xFF335066),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (service.providerDistanceKm != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4F7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${service.providerDistanceKm!.toStringAsFixed(1)} km away',
                              style: const TextStyle(
                                color: Color(0xFF335066),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (!service.available)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Unavailable on selected date',
                              style: TextStyle(
                                color: Color(0xFFC62828),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (compact)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: service.available ? onBook : null,
                            icon: const Icon(Icons.shopping_bag_outlined),
                            label: Text(service.available ? 'Book Service' : 'Not Available'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: onProviderDetails,
                            icon: const Icon(Icons.person_outline_rounded),
                            label: const Text('Provider Details'),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: service.available ? onBook : null,
                            icon: const Icon(Icons.shopping_bag_outlined),
                            label: Text(service.available ? 'Book Service' : 'Not Available'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onProviderDetails,
                            icon: const Icon(Icons.person_outline_rounded),
                            label: const Text('Provider Details'),
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ServiceMeta {
  final IconData icon;
  final Color color;
  final String badge;
  final String hint;

  const _ServiceMeta({
    required this.icon,
    required this.color,
    required this.badge,
    required this.hint,
  });
}

_ServiceMeta _serviceMeta(String serviceName) {
  final key = serviceName.toLowerCase();

  if (key == 'plumber') {
    return const _ServiceMeta(
      icon: Icons.plumbing_rounded,
      color: Color(0xFF0E6F67),
      badge: 'Water & Pipe',
      hint: 'Leak fixes, fittings, and urgent repairs',
    );
  }

  if (key == 'electrician') {
    return const _ServiceMeta(
      icon: Icons.electrical_services_rounded,
      color: Color(0xFFCC8B24),
      badge: 'Power & Wiring',
      hint: 'Switchboard, wiring, and appliance support',
    );
  }

  return const _ServiceMeta(
    icon: Icons.miscellaneous_services_rounded,
    color: Color(0xFF607D8B),
    badge: 'General',
    hint: 'Trusted local support near you',
  );
}

ImageProvider<Object>? _providerImageFromService(ServiceModel service) {
  final providerImageBase64 = service.providerProfileImageBase64?.trim() ?? '';

  if (providerImageBase64.isNotEmpty) {
    try {
      final providerImageBytes = base64Decode(providerImageBase64);
      return MemoryImage(providerImageBytes);
    } catch (_) {
      // Fall back to URL/avatar icon when image decoding fails.
    }
  }

  final imageUrl = service.providerProfileImageUrl?.trim() ?? '';
  if (imageUrl.isNotEmpty) {
    return NetworkImage(imageUrl);
  }

  return null;
}

class _ProviderDetailsSheet extends StatelessWidget {
  final ServiceModel service;

  const _ProviderDetailsSheet({required this.service});

  Future<String> _resolveLiveLocationLabel() async {
    final latitude = service.providerLiveLatitude;
    final longitude = service.providerLiveLongitude;
    if (latitude == null || longitude == null) {
      return 'Current location shared';
    }

    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = <String?>[
          place.subLocality,
          place.locality,
          place.administrativeArea,
        ]
            .map((part) => (part ?? '').trim())
            .where((part) => part.isNotEmpty)
            .toList();
        if (parts.isNotEmpty) {
          return parts.take(2).join(', ');
        }
      }
    } catch (_) {
      // Fall back to a generic label when reverse geocoding fails.
    }

    return 'Current location shared';
  }

  @override
  Widget build(BuildContext context) {
    final providerName = service.providerName ?? 'Provider';
    final providerCity = service.providerCity?.trim() ?? '';
    final providerState = service.providerState?.trim() ?? '';
    final providerAddress = service.providerAddress?.trim() ?? '';
    final providerContact = service.providerContactNumber?.trim() ?? '';
    final providerSkills = service.providerSkills?.trim() ?? '';
    final providerBio = service.providerBio?.trim() ?? '';
    final providerImage = _providerImageFromService(service);

    final locationParts = [
      if (providerCity.isNotEmpty) providerCity,
      if (providerState.isNotEmpty) providerState,
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5FBFA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFD4ECE8),
                    backgroundImage: providerImage,
                    child: providerImage == null
                        ? const Icon(
                            Icons.person_rounded,
                            color: AppTheme.brand,
                            size: 30,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          providerName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          service.providerVerified
                              ? 'Verified Provider'
                              : 'Provider',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDF3EE),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Rating ${service.providerRatingAverage.toStringAsFixed(1)} (${service.providerTotalReviews} reviews)',
                      style: const TextStyle(
                        color: Color(0xFF0E6F67),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (service.providerExperienceYears != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${service.providerExperienceYears} yrs experience',
                        style: const TextStyle(
                          color: Color(0xFF335066),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (locationParts.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        locationParts.join(', '),
                        style: const TextStyle(
                          color: Color(0xFF335066),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (service.providerDistanceKm != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${service.providerDistanceKm!.toStringAsFixed(1)} km away',
                        style: const TextStyle(
                          color: Color(0xFF335066),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              if (service.providerLiveLocationSharingEnabled &&
                  service.providerLiveLatitude != null &&
                  service.providerLiveLongitude != null) ...[
                const SizedBox(height: 10),
                FutureBuilder<String>(
                  future: _resolveLiveLocationLabel(),
                  builder: (context, snapshot) {
                    return _DetailRow(
                      icon: Icons.my_location_rounded,
                      label: 'Live Location',
                      value: snapshot.data ?? 'Resolving location...',
                    );
                  },
                ),
              ],
              if (providerContact.isNotEmpty) ...[
                const SizedBox(height: 14),
                _DetailRow(icon: Icons.phone_outlined, label: 'Contact', value: providerContact),
              ],
              if (providerAddress.isNotEmpty) ...[
                const SizedBox(height: 10),
                _DetailRow(icon: Icons.home_outlined, label: 'Address', value: providerAddress),
              ],
              if (providerSkills.isNotEmpty) ...[
                const SizedBox(height: 10),
                _DetailRow(icon: Icons.handyman_outlined, label: 'Skills', value: providerSkills),
              ],
              if (providerBio.isNotEmpty) ...[
                const SizedBox(height: 10),
                _DetailRow(icon: Icons.notes_outlined, label: 'Bio', value: providerBio),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF335066)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppTheme.brand.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.search_off_rounded,
                    size: 34,
                    color: AppTheme.brand,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No services available right now',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Pull to refresh or tap below to retry.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: 180,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      onRefresh();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry Now'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeroPill({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFEAF9F5)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFFEAF9F5),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterStatusChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FilterStatusChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6F3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.brand),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.brand,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}