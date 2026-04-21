import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/booking_model.dart';
import '../models/provider_earnings_model.dart';
import '../models/review_model.dart';
import '../models/service_model.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/server_warmup_loading.dart';
import 'auth_screen.dart';

enum _ProviderServiceSort {
  newest,
  priceLowToHigh,
  priceHighToLow,
  nameAZ,
}

enum _ProviderServiceAction {
  edit,
  delete,
}

class ProviderDashboardScreen extends StatefulWidget {
  final int userId;
  final String userName;

  const ProviderDashboardScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<ProviderDashboardScreen> createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  static const String _customServiceOption = '__custom_service_option__';

  // Built-in catalog to ensure the provider can pick from a rich set of service types.
  static const List<String> _defaultServiceTypes = [
    'AC Service',
    'Appliance Installation',
    'Baby Sitting',
    'Bathroom Cleaning',
    'Beautician at Home',
    'Bike Service',
    'Car Wash',
    'Carpenter',
    'CCTV Installation',
    'Computer Repair',
    'Deep Cleaning',
    'Driver on Demand',
    'Electrician',
    'Elder Care',
    'Event Photographer',
    'Fitness Trainer',
    'Gas Stove Repair',
    'Geyser Repair',
    'Home Painting',
    'Home Tutor',
    'Home Sanitization',
    'Interior Designer',
    'Kitchen Cleaning',
    'Laptop Repair',
    'Makeup Artist',
    'Mobile Repair',
    'Nursing Care',
    'Packers and Movers',
    'Pest Control',
    'Pet Grooming',
    'Physiotherapist',
    'Plumber',
    'Refrigerator Repair',
    'RO Water Purifier Service',
    'Salon at Home',
    'Sofa Cleaning',
    'Tailor and Alteration',
    'TV Repair',
    'Washing Machine Repair',
    'Wedding Planner',
    'Yoga Trainer',
  ];

  final _customNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _experienceController = TextEditingController();
  final _skillsController = TextEditingController();
  final _bioController = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _isLoading = true;
  bool _showWarmupHint = false;
  bool _isSaving = false;
  bool _isProfileSaving = false;
  bool _isLocationSyncing = false;
  bool _liveShareEnabled = false;
  int? _editingServiceId;
  int? _deletingServiceId;
  int? _statusUpdatingBookingId;
  int? _replyingReviewId;
  List<ServiceModel> _myServices = [];
  List<BookingModel> _providerBookings = [];
  List<ReviewModel> _providerReviews = [];
  List<String> _serviceTypes = [];
  ProviderEarningsModel? _earnings;
  String _displayName = '';
  UserProfile? _providerProfile;
  String? _selectedServiceType;
  String _searchQuery = '';
  _ProviderServiceSort _sortBy = _ProviderServiceSort.newest;
  int _loadRequestVersion = 0;
  Timer? _liveLocationTimer;
  final Map<int, TextEditingController> _reviewReplyControllers = {};
  Uint8List? _selectedProfileImageBytes;
  String? _selectedProfileImageName;
  bool _profileImageDirty = false;

  @override
  void initState() {
    super.initState();
    _displayName = widget.userName.trim();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _customNameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _experienceController.dispose();
    _skillsController.dispose();
    _bioController.dispose();
    _liveLocationTimer?.cancel();
    for (final controller in _reviewReplyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    final requestVersion = ++_loadRequestVersion;
    setState(() {
      _isLoading = true;
      _showWarmupHint = false;
    });

    Timer(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      if (_isLoading && requestVersion == _loadRequestVersion) {
        setState(() {
          _showWarmupHint = true;
        });
      }
    });

    try {
      final results = await Future.wait([
        ApiService.getProviderServices(widget.userId),
        ApiService.getUserProfile(widget.userId),
        ApiService.getServiceTypes(),
        ApiService.getProviderBookings(widget.userId),
        ApiService.getProviderReviews(widget.userId),
        ApiService.getProviderEarnings(providerId: widget.userId),
      ]);

      final services = results[0] as List<ServiceModel>;
      final profile = results[1] as UserProfile;
      final serviceTypes = _normalizeServiceTypes(results[2] as List<String>);
      final providerBookings = results[3] as List<BookingModel>;
      final providerReviews = results[4] as List<ReviewModel>;
      final earnings = results[5] as ProviderEarningsModel;

      _bindProviderProfileFields(profile);
      _syncReviewReplyControllers(providerReviews);

      if (!mounted) return;
      setState(() {
        _myServices = services;
        _providerBookings = providerBookings;
        _providerReviews = providerReviews;
        _earnings = earnings;
        _displayName = profile.name;
        _providerProfile = profile;
        _liveShareEnabled = profile.liveLocationSharingEnabled;
        _serviceTypes = serviceTypes;

        if (_selectedServiceType == null) {
          _selectedServiceType = serviceTypes.isNotEmpty
            ? serviceTypes.first
            : _customServiceOption;
        } else if (_selectedServiceType != _customServiceOption
            && !serviceTypes.contains(_selectedServiceType)) {
          _selectedServiceType = serviceTypes.isNotEmpty
            ? serviceTypes.first
            : _customServiceOption;
        }
      });

      _refreshLiveLocationTimer();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _bindProviderProfileFields(UserProfile profile) {
    _contactController.text = profile.contactNumber ?? '';
    _addressController.text = profile.address ?? '';
    _cityController.text = profile.city ?? '';
    _stateController.text = profile.state ?? '';
    _pincodeController.text = profile.pincode ?? '';
    _experienceController.text = profile.experienceYears?.toString() ?? '';
    _skillsController.text = profile.skills ?? '';
    _bioController.text = profile.bio ?? '';

    if (!_profileImageDirty) {
      final imageBase64 = profile.profileImageBase64;
      if (imageBase64 != null && imageBase64.trim().isNotEmpty) {
        try {
          _selectedProfileImageBytes = base64Decode(imageBase64);
          _selectedProfileImageName = 'profile_image';
        } catch (_) {
          _selectedProfileImageBytes = null;
          _selectedProfileImageName = null;
        }
      } else {
        _selectedProfileImageBytes = null;
        _selectedProfileImageName = null;
      }
    }
  }

  List<String> _normalizeServiceTypes(List<String> rawTypes) {
    final merged = <String>[
      ..._defaultServiceTypes,
      ...rawTypes,
    ];

    final byKey = <String, String>{};
    for (final item in merged) {
      final clean = item.trim();
      if (clean.isEmpty) {
        continue;
      }
      byKey.putIfAbsent(clean.toLowerCase(), () => clean);
    }

    final normalized = byKey.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return normalized;
  }

  List<ServiceModel> _visibleServices() {
    final query = _searchQuery.trim().toLowerCase();

    final filtered = _myServices.where((service) {
      if (query.isEmpty) {
        return true;
      }

      final name = service.name.toLowerCase();
      final description = (service.description ?? '').toLowerCase();
      return name.contains(query) || description.contains(query);
    }).toList();

    switch (_sortBy) {
      case _ProviderServiceSort.newest:
        filtered.sort((a, b) => b.id.compareTo(a.id));
        break;
      case _ProviderServiceSort.priceLowToHigh:
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case _ProviderServiceSort.priceHighToLow:
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
      case _ProviderServiceSort.nameAZ:
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }

    return filtered;
  }

  double get _averagePrice {
    if (_myServices.isEmpty) {
      return 0;
    }

    final total = _myServices.fold<double>(0, (sum, item) => sum + item.price);
    return total / _myServices.length;
  }

  int get _customTypeCount {
    final knownTypes = _defaultServiceTypes.map((item) => item.toLowerCase()).toSet();
    return _myServices
      .where((service) => !knownTypes.contains(service.name.trim().toLowerCase()))
      .length;
  }

  List<DropdownMenuItem<String>> _serviceTypeItems() {
    final items = _serviceTypes
      .map(
        (type) => DropdownMenuItem<String>(
          value: type,
          child: Text(type),
        ),
      )
      .toList();

    items.add(
      const DropdownMenuItem<String>(
        value: _customServiceOption,
        child: Text('Custom (Type your own)'),
      ),
    );

    return items;
  }

  String? _selectedServiceName() {
    if (_selectedServiceType == null) {
      return null;
    }

    if (_selectedServiceType == _customServiceOption) {
      final customName = _customNameController.text.trim();
      return customName.isEmpty ? null : customName;
    }

    return _selectedServiceType;
  }

  Future<void> _submitService() async {
    final selectedName = _selectedServiceName();
    final description = _descriptionController.text.trim();
    final price = double.tryParse(_priceController.text.trim());

    if (selectedName == null || description.isEmpty || price == null) {
      _showMessage(
        'Please select a service type, enter valid price and description.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (_editingServiceId == null) {
        await ApiService.createServiceByProvider(
          providerId: widget.userId,
          name: selectedName,
          price: price,
          description: description,
        );
        _showMessage('Service published successfully');
      } else {
        await ApiService.updateServiceByProvider(
          serviceId: _editingServiceId!,
          providerId: widget.userId,
          name: selectedName,
          price: price,
          description: description,
        );
        _showMessage('Service updated successfully');
      }

      _resetForm();
      await _loadDashboardData();
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _startEditing(ServiceModel service) {
    final serviceName = service.name.trim();
    final isKnownType = _serviceTypes.contains(serviceName);

    setState(() {
      _editingServiceId = service.id;
      _selectedServiceType = isKnownType ? serviceName : _customServiceOption;
      _customNameController.text = isKnownType ? '' : serviceName;
      _priceController.text = service.price % 1 == 0
        ? service.price.toStringAsFixed(0)
        : service.price.toString();
      _descriptionController.text = service.description ?? '';
    });
  }

  Future<void> _deleteService(ServiceModel service) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Service'),
          content: Text('Delete "${service.name}" from your published services?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      _deletingServiceId = service.id;
    });

    try {
      await ApiService.deleteServiceByProvider(
        serviceId: service.id,
        providerId: widget.userId,
      );

      if (_editingServiceId == service.id) {
        _resetForm();
      }

      await _loadDashboardData();
      _showMessage('Service deleted successfully');
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _deletingServiceId = null;
        });
      }
    }
  }

  Future<void> _handleServiceAction(
    _ProviderServiceAction action,
    ServiceModel service,
  ) async {
    switch (action) {
      case _ProviderServiceAction.edit:
        _startEditing(service);
        break;
      case _ProviderServiceAction.delete:
        await _deleteService(service);
        break;
    }
  }

  void _resetForm() {
    setState(() {
      _editingServiceId = null;
      _customNameController.clear();
      _priceController.clear();
      _descriptionController.clear();
      _selectedServiceType = _serviceTypes.isNotEmpty
        ? _serviceTypes.first
        : _customServiceOption;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  void _applyPricePreset(int value) {
    setState(() {
      _priceController.text = value.toString();
    });
  }

  void _syncReviewReplyControllers(List<ReviewModel> reviews) {
    final validIds = reviews.map((review) => review.id).toSet();

    final obsoleteKeys = _reviewReplyControllers.keys
        .where((key) => !validIds.contains(key))
        .toList();
    for (final key in obsoleteKeys) {
      _reviewReplyControllers.remove(key)?.dispose();
    }

    for (final review in reviews) {
      _reviewReplyControllers.putIfAbsent(
        review.id,
        () => TextEditingController(),
      );
    }
  }

  Future<ImageSource?> _selectImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickProfileImage() async {
    try {
      final source = await _selectImageSource();
      if (source == null) {
        return;
      }

      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (image == null) {
        return;
      }

      final bytes = await image.readAsBytes();
      if (bytes.length > 3 * 1024 * 1024) {
        _showMessage('Image size must be <= 3 MB.');
        return;
      }

      setState(() {
        _selectedProfileImageBytes = bytes;
        _selectedProfileImageName = image.name;
        _profileImageDirty = true;
      });
    } catch (_) {
      _showMessage('Unable to pick image. Please check camera/media permissions.');
    }
  }

  Future<void> _removeProfileImage() async {
    setState(() {
      _isProfileSaving = true;
    });

    try {
      final updatedProfile = await ApiService.removeProfileImage(
        userId: widget.userId,
      );

      if (!mounted) return;
      setState(() {
        _providerProfile = updatedProfile;
        _selectedProfileImageBytes = null;
        _selectedProfileImageName = null;
        _profileImageDirty = false;
      });
      _showMessage('Profile image removed');
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isProfileSaving = false;
        });
      }
    }
  }

  void _refreshLiveLocationTimer() {
    _liveLocationTimer?.cancel();
    if (!_liveShareEnabled) {
      return;
    }

    _liveLocationTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) {
        _syncCurrentLocation(showSuccessMessage: false);
      },
    );
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage('Please enable device location services.');
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
      _showMessage('Location permission is required for live tracking.');
      return false;
    }

    return true;
  }

  Future<void> _syncCurrentLocation({bool showSuccessMessage = true}) async {
    if (_isLocationSyncing) {
      return;
    }

    if (!_liveShareEnabled) {
      _showMessage('Enable live location sharing first.');
      return;
    }

    final allowed = await _ensureLocationPermission();
    if (!allowed) {
      return;
    }

    setState(() {
      _isLocationSyncing = true;
    });

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final updated = await ApiService.updateProviderLocation(
        userId: widget.userId,
        liveLocationSharingEnabled: true,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;
      setState(() {
        _providerProfile = updated;
      });

      if (showSuccessMessage) {
        _showMessage('Live location updated');
      }
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isLocationSyncing = false;
        });
      }
    }
  }

  Future<void> _toggleLiveLocationSharing(bool enabled) async {
    setState(() {
      _liveShareEnabled = enabled;
    });

    try {
      final updated = await ApiService.updateProviderLocation(
        userId: widget.userId,
        liveLocationSharingEnabled: enabled,
      );

      if (!mounted) return;
      setState(() {
        _providerProfile = updated;
      });

      _refreshLiveLocationTimer();
      if (enabled) {
        await _syncCurrentLocation(showSuccessMessage: false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _liveShareEnabled = !enabled;
      });
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _requestLocationPermissionFromCenter() async {
    final allowed = await _ensureLocationPermission();
    if (allowed) {
      _showMessage('Location permission is available.');
    }
  }

  Future<void> _requestCameraPermissionFromCenter() {
    return _requestImagePermissionFromSource(ImageSource.camera);
  }

  Future<void> _requestPhotosPermissionFromCenter() {
    return _requestImagePermissionFromSource(ImageSource.gallery);
  }

  Future<void> _requestImagePermissionFromSource(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1280,
      );

      if (!mounted) {
        return;
      }

      final sourceLabel = source == ImageSource.camera ? 'Camera' : 'Photos';
      if (image == null) {
        _showMessage('$sourceLabel access checked.');
      } else {
        _showMessage('$sourceLabel permission is available.');
      }
    } catch (_) {
      final sourceLabel = source == ImageSource.camera ? 'camera' : 'photos';
      _showMessage(
        'Unable to access $sourceLabel. Please allow permission from app settings.',
      );
    }
  }

  Future<void> _openAppSettingsFromCenter() async {
    final opened = await Geolocator.openAppSettings();
    if (!opened && mounted) {
      _showMessage('Unable to open app settings on this device.');
    }
  }

  Future<void> _openLocationSettingsFromCenter() async {
    final opened = await Geolocator.openLocationSettings();
    if (!opened && mounted) {
      _showMessage('Unable to open location settings on this device.');
    }
  }

  Future<void> _updateBookingStatus(
    BookingModel booking,
    String status,
  ) async {
    setState(() {
      _statusUpdatingBookingId = booking.id;
    });

    try {
      await ApiService.updateBookingStatusByProvider(
        bookingId: booking.id,
        providerId: widget.userId,
        status: status,
      );

      await _loadDashboardData();
      _showMessage('Booking updated to $status');
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _statusUpdatingBookingId = null;
        });
      }
    }
  }

  Future<void> _replyToReview(ReviewModel review) async {
    final controller = _reviewReplyControllers[review.id];
    final reply = controller?.text.trim() ?? '';

    if (reply.isEmpty) {
      _showMessage('Please write a reply first.');
      return;
    }

    setState(() {
      _replyingReviewId = review.id;
    });

    try {
      await ApiService.replyToReview(
        reviewId: review.id,
        providerId: widget.userId,
        response: reply,
      );

      await _loadDashboardData();
      _showMessage('Reply submitted');
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _replyingReviewId = null;
        });
      }
    }
  }

  Future<void> _saveProviderProfile() async {
    final contactNumber = _contactController.text.trim();
    final address = _addressController.text.trim();
    final city = _cityController.text.trim();

    if (contactNumber.isEmpty || address.isEmpty || city.isEmpty) {
      _showMessage('Contact number, address, and city are required.');
      return;
    }

    int? experienceYears;
    if (_experienceController.text.trim().isNotEmpty) {
      experienceYears = int.tryParse(_experienceController.text.trim());
      if (experienceYears == null || experienceYears < 0) {
        _showMessage('Experience must be a valid non-negative number.');
        return;
      }
    }

    setState(() {
      _isProfileSaving = true;
    });

    try {
      var updatedProfile = await ApiService.updateProviderProfile(
        userId: widget.userId,
        contactNumber: contactNumber,
        address: address,
        city: city,
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        experienceYears: experienceYears,
        skills: _skillsController.text.trim(),
        bio: _bioController.text.trim(),
      );

      if (_profileImageDirty && _selectedProfileImageBytes != null) {
        updatedProfile = await ApiService.uploadProfileImage(
          userId: widget.userId,
          fileBytes: _selectedProfileImageBytes!,
          fileName: _selectedProfileImageName ?? 'provider_profile.jpg',
        );
      }

      if (!mounted) return;
      setState(() {
        _providerProfile = updatedProfile;
        _profileImageDirty = false;
      });
      _showMessage('Provider profile updated successfully');
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isProfileSaving = false;
        });
      }
    }
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'PENDING' => 'Pending',
      'CONFIRMED' => 'Confirmed',
      'IN_PROGRESS' => 'In Progress',
      'COMPLETED' => 'Completed',
      'CANCELLED' => 'Cancelled',
      _ => status,
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'PENDING' => const Color(0xFF7A8A99),
      'CONFIRMED' => const Color(0xFF0E6F67),
      'IN_PROGRESS' => const Color(0xFFCC8B24),
      'COMPLETED' => const Color(0xFF0A7D5B),
      'CANCELLED' => const Color(0xFFC0392B),
      _ => const Color(0xFF607D8B),
    };
  }

  @override
  Widget build(BuildContext context) {
    final visibleServices = _visibleServices();
    final hasActiveFilter = _searchQuery.trim().isNotEmpty;
    final providerProfile = _providerProfile;
    final earnings = _earnings;
    final providerBookings = _providerBookings;
    final providerReviews = _providerReviews;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadDashboardData,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 210,
                  pinned: true,
                  floating: false,
                  surfaceTintColor: Colors.transparent,
                  backgroundColor: const Color(0xFF0E6F67),
                  title: const Text(
                    'Provider Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 12, 8),
                      child: TextButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('Logout'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                      padding: const EdgeInsets.fromLTRB(18, 64, 18, 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0E6F67), Color(0xFF184B46)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.white.withValues(alpha: 0.22),
                                child: const Icon(
                                  Icons.storefront_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Hello, ${_displayName.isEmpty ? 'Provider' : _displayName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Manage services, prices, and descriptions like a production provider app.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFFE5F6F3),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            label: 'Total',
                            value: '${_myServices.length}',
                            icon: Icons.inventory_2_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MetricCard(
                            label: 'Avg Price',
                            value: 'Rs ${_averagePrice.toStringAsFixed(0)}',
                            icon: Icons.payments_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MetricCard(
                            label: 'Custom',
                            value: '$_customTypeCount',
                            icon: Icons.auto_awesome_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Provider Profile',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                ),
                                if (providerProfile != null && providerProfile.verified)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD8F3E8),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Verified',
                                      style: TextStyle(
                                        color: Color(0xFF0A7D5B),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'These details are visible to customers while booking your service.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _contactController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Contact Number *',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                labelText: 'Address *',
                                prefixIcon: Icon(Icons.home_outlined),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _cityController,
                              decoration: const InputDecoration(
                                labelText: 'City *',
                                prefixIcon: Icon(Icons.location_city_outlined),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _stateController,
                                    decoration: const InputDecoration(
                                      labelText: 'State',
                                      prefixIcon: Icon(Icons.map_outlined),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _pincodeController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Pincode',
                                      prefixIcon: Icon(Icons.pin_drop_outlined),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFD4DDE2)),
                                color: const Color(0xFFF9FCFB),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Profile Image (stored in database)',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        width: 58,
                                        height: 58,
                                        clipBehavior: Clip.antiAlias,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE7F0EE),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: _selectedProfileImageBytes == null
                                            ? const Icon(Icons.person_outline_rounded)
                                            : Image.memory(
                                                _selectedProfileImageBytes!,
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _selectedProfileImageName ?? 'No image selected',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: _isProfileSaving ? null : _pickProfileImage,
                                        icon: const Icon(Icons.upload_file_rounded),
                                        label: const Text('Choose Image'),
                                      ),
                                      if (_selectedProfileImageBytes != null)
                                        OutlinedButton.icon(
                                          onPressed: _isProfileSaving ? null : _removeProfileImage,
                                          icon: const Icon(Icons.delete_outline_rounded),
                                          label: const Text('Remove'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _experienceController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Experience (years)',
                                      prefixIcon: Icon(Icons.work_history_outlined),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _skillsController,
                                    decoration: const InputDecoration(
                                      labelText: 'Skills',
                                      prefixIcon: Icon(Icons.handyman_outlined),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _bioController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Professional Bio',
                                prefixIcon: Icon(Icons.notes_outlined),
                              ),
                            ),
                            if (providerProfile != null) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: const Color(0xFFD8DFE2)),
                                    ),
                                    child: Text(
                                      'Rating ${providerProfile.ratingAverage.toStringAsFixed(1)} (${providerProfile.totalReviews} reviews)',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isProfileSaving ? null : _saveProviderProfile,
                                icon: _isProfileSaving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_as_rounded),
                                label: Text(
                                  _isProfileSaving ? 'Saving Profile...' : 'Save Provider Profile',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Permission Center',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Grant permissions for location sync, camera capture, and photo uploads. These permissions also appear in your device app settings.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: const [
                                _PermissionChip(
                                  icon: Icons.location_on_outlined,
                                  text: 'Location',
                                ),
                                _PermissionChip(
                                  icon: Icons.photo_camera_outlined,
                                  text: 'Camera',
                                ),
                                _PermissionChip(
                                  icon: Icons.photo_library_outlined,
                                  text: 'Photos / Files',
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _requestLocationPermissionFromCenter,
                                  icon: const Icon(Icons.my_location_rounded),
                                  label: const Text('Ask Location'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _requestCameraPermissionFromCenter,
                                  icon: const Icon(Icons.photo_camera_outlined),
                                  label: const Text('Ask Camera'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _requestPhotosPermissionFromCenter,
                                  icon: const Icon(Icons.photo_library_outlined),
                                  label: const Text('Ask Photos'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                TextButton.icon(
                                  onPressed: _openAppSettingsFromCenter,
                                  icon: const Icon(Icons.settings_outlined),
                                  label: const Text('Open App Settings'),
                                ),
                                TextButton.icon(
                                  onPressed: _openLocationSettingsFromCenter,
                                  icon: const Icon(Icons.location_searching_rounded),
                                  label: const Text('Open Location Settings'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Live Location Sharing',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Share your current device location to power live order tracking.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 10),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _liveShareEnabled,
                              onChanged: _isLocationSyncing ? null : _toggleLiveLocationSharing,
                              title: const Text('Enable live location sharing'),
                              subtitle: Text(
                                _liveShareEnabled
                                    ? 'Customers can track your current location during active orders.'
                                    : 'Customers will only see booking status updates.',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    providerProfile?.liveLatitude == null ||
                                            providerProfile?.liveLongitude == null
                                        ? 'No location synced yet'
                                        : 'Lat ${providerProfile!.liveLatitude!.toStringAsFixed(5)}, Lng ${providerProfile.liveLongitude!.toStringAsFixed(5)}',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: (!_liveShareEnabled || _isLocationSyncing)
                                      ? null
                                      : () => _syncCurrentLocation(),
                                  icon: _isLocationSyncing
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.my_location_rounded),
                                  label: Text(_isLocationSyncing ? 'Syncing' : 'Sync Now'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Earning Dashboard',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _StatPill(
                                  label: 'Total',
                                  value: 'Rs ${(earnings?.totalEarnings ?? 0).toStringAsFixed(0)}',
                                ),
                                _StatPill(
                                  label: 'Today',
                                  value: 'Rs ${(earnings?.todayEarnings ?? 0).toStringAsFixed(0)}',
                                ),
                                _StatPill(
                                  label: 'Month',
                                  value: 'Rs ${(earnings?.thisMonthEarnings ?? 0).toStringAsFixed(0)}',
                                ),
                                _StatPill(
                                  label: 'Completed',
                                  value: '${earnings?.completedOrders ?? 0}',
                                ),
                              ],
                            ),
                            if (earnings != null && earnings.recentCompletedOrders.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Recent completed orders',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              ...earnings.recentCompletedOrders.take(4).map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F9F8),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.serviceName ?? 'Service',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          'Rs ${item.amount.toStringAsFixed(0)}',
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order Tracking Management',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            if (providerBookings.isEmpty)
                              Text(
                                'No provider bookings yet.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              )
                            else
                              ...providerBookings.take(8).map(
                                (booking) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFDCE4E8)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                booking.serviceName ?? 'Service #${booking.serviceId}',
                                                style: const TextStyle(fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _statusColor(booking.status).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                _statusLabel(booking.status),
                                                style: TextStyle(
                                                  color: _statusColor(booking.status),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text('Date: ${booking.date}'),
                                        if (booking.trackingNote != null &&
                                            booking.trackingNote!.trim().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text('Note: ${booking.trackingNote}'),
                                          ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: ['CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']
                                              .map(
                                                (status) => ActionChip(
                                                  onPressed: _statusUpdatingBookingId == booking.id ||
                                                          booking.status == status
                                                      ? null
                                                      : () => _updateBookingStatus(booking, status),
                                                  label: Text(_statusLabel(status)),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Review Management',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            if (providerReviews.isEmpty)
                              Text(
                                'No customer reviews yet.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              )
                            else
                              ...providerReviews.take(8).map(
                                (review) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFDCE4E8)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                review.serviceName ?? 'Service #${review.serviceId}',
                                                style: const TextStyle(fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                            Text('Rating ${review.rating}/5'),
                                          ],
                                        ),
                                        if (review.comment != null &&
                                            review.comment!.trim().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Text(review.comment!),
                                          ),
                                        const SizedBox(height: 8),
                                        if (review.providerResponse != null &&
                                            review.providerResponse!.trim().isNotEmpty)
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F7F5),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text('Your reply: ${review.providerResponse}'),
                                          )
                                        else ...[
                                          TextField(
                                            controller: _reviewReplyControllers[review.id],
                                            maxLines: 2,
                                            decoration: const InputDecoration(
                                              labelText: 'Write a reply',
                                              prefixIcon: Icon(Icons.reply_rounded),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: ElevatedButton.icon(
                                              onPressed: _replyingReviewId == review.id
                                                  ? null
                                                  : () => _replyToReview(review),
                                              icon: _replyingReviewId == review.id
                                                  ? const SizedBox(
                                                      width: 14,
                                                      height: 14,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                    )
                                                  : const Icon(Icons.send_rounded),
                                              label: const Text('Reply'),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _editingServiceId == null
                                      ? 'Publish New Service'
                                      : 'Update Service',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                ),
                                if (_editingServiceId != null)
                                  TextButton.icon(
                                    onPressed: _isSaving ? null : _resetForm,
                                    icon: const Icon(Icons.restart_alt_rounded),
                                    label: const Text('Clear'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              key: ValueKey<String?>(_selectedServiceType),
                              initialValue: _selectedServiceType,
                              isExpanded: true,
                              menuMaxHeight: 420,
                              decoration: const InputDecoration(
                                labelText: 'Service Type',
                                prefixIcon: Icon(Icons.list_alt_rounded),
                              ),
                              items: _serviceTypeItems(),
                              onChanged: _isSaving
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedServiceType = value;
                                    });
                                  },
                            ),
                            if (_selectedServiceType == _customServiceOption) ...[
                              const SizedBox(height: 10),
                              TextField(
                                controller: _customNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Custom Service Name',
                                  prefixIcon: Icon(Icons.edit_note_rounded),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            TextField(
                              controller: _priceController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Price',
                                prefixIcon: Icon(Icons.currency_rupee_rounded),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _descriptionController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Service Details',
                                prefixIcon: Icon(Icons.description_outlined),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [300, 500, 800, 1200, 1500]
                                .map(
                                  (value) => ActionChip(
                                    onPressed: _isSaving
                                      ? null
                                      : () => _applyPricePreset(value),
                                    avatar: const Icon(
                                      Icons.flash_on_rounded,
                                      size: 16,
                                    ),
                                    label: Text('Rs $value'),
                                  ),
                                )
                                .toList(),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isSaving ? null : _submitService,
                                    icon: _isSaving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Icon(
                                          _editingServiceId == null
                                            ? Icons.add_circle_outline
                                            : Icons.save_outlined,
                                        ),
                                    label: Text(
                                      _isSaving
                                        ? (_editingServiceId == null
                                            ? 'Publishing...'
                                            : 'Updating...')
                                        : (_editingServiceId == null
                                            ? 'Publish Service'
                                            : 'Update Service'),
                                    ),
                                  ),
                                ),
                                if (_editingServiceId != null) ...[
                                  const SizedBox(width: 10),
                                  OutlinedButton(
                                    onPressed: _isSaving ? null : _resetForm,
                                    child: const Text('Cancel'),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: 'Search your published services',
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon: _searchQuery.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      onPressed: _clearSearch,
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<_ProviderServiceSort>(
                              initialValue: _sortBy,
                              decoration: const InputDecoration(
                                labelText: 'Sort by',
                                prefixIcon: Icon(Icons.sort_rounded),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: _ProviderServiceSort.newest,
                                  child: Text('Newest first'),
                                ),
                                DropdownMenuItem(
                                  value: _ProviderServiceSort.priceLowToHigh,
                                  child: Text('Price: Low to high'),
                                ),
                                DropdownMenuItem(
                                  value: _ProviderServiceSort.priceHighToLow,
                                  child: Text('Price: High to low'),
                                ),
                                DropdownMenuItem(
                                  value: _ProviderServiceSort.nameAZ,
                                  child: Text('Name: A to Z'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _sortBy = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Text(
                      _isLoading
                        ? (_showWarmupHint
                            ? 'Warming up backend and loading your services...'
                            : 'Loading your services...')
                        : '${visibleServices.length} of ${_myServices.length} services shown',
                      style: Theme.of(context).textTheme.bodyMedium,
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
                          title: 'Syncing provider dashboard',
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.builder(
                        itemCount: 4,
                        itemBuilder: (context, index) => const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: ServiceSkeletonCard(showActionButton: false),
                        ),
                      ),
                    ),
                  ]
                else if (visibleServices.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ProviderEmptyState(
                      hasActiveFilter: hasActiveFilter,
                      onClearFilter: hasActiveFilter ? _clearSearch : null,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.builder(
                      itemCount: visibleServices.length,
                      itemBuilder: (context, index) {
                        final service = visibleServices[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFD5ECE8),
                                foregroundColor: AppTheme.brand,
                                child: Icon(Icons.verified_outlined),
                              ),
                              title: Text(service.name),
                              subtitle: Text(
                                '${service.description ?? ''}\nPrice: Rs ${service.price.toStringAsFixed(0)}',
                              ),
                              isThreeLine: true,
                              trailing: _deletingServiceId == service.id
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : PopupMenuButton<_ProviderServiceAction>(
                                    tooltip: 'Service actions',
                                    onSelected: (action) {
                                      _handleServiceAction(action, service);
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: _ProviderServiceAction.edit,
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(Icons.edit_outlined),
                                          title: Text('Edit'),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: _ProviderServiceAction.delete,
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(Icons.delete_outline),
                                          title: Text('Delete'),
                                        ),
                                      ),
                                    ],
                                  ),
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
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppTheme.brand),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8F7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD4E0DE)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PermissionChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PermissionChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF6F4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD7E7E3)),
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

class _ProviderEmptyState extends StatelessWidget {
  final bool hasActiveFilter;
  final VoidCallback? onClearFilter;

  const _ProviderEmptyState({
    required this.hasActiveFilter,
    this.onClearFilter,
  });

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
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFD5ECE8),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: AppTheme.brand,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  hasActiveFilter
                    ? 'No services match your search'
                    : 'No services published yet',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  hasActiveFilter
                    ? 'Try a different keyword or clear search filters.'
                    : 'Use the form above to publish your first service.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                if (hasActiveFilter && onClearFilter != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onClearFilter,
                    icon: const Icon(Icons.filter_alt_off_rounded),
                    label: const Text('Clear Filters'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
