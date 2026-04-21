import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/india_location_data.dart';
import '../widgets/app_background.dart';
import '../widgets/server_selector_sheet.dart';
import 'provider_dashboard_screen.dart';
import 'service_list_screen.dart';

enum _PortalType { customer, provider }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with WidgetsBindingObserver {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _experienceController = TextEditingController();
  final _skillsController = TextEditingController();
  final _bioController = TextEditingController();
  final _providerRegistrationFormKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final ScrollController _scrollController =
      ScrollController(keepScrollOffset: false);

  bool _isLogin = true;
  bool _isLoading = false;
  _PortalType _portalType = _PortalType.customer;
  Uint8List? _selectedProfileImageBytes;
  String? _selectedProfileImageName;
  String? _selectedState;
  String? _selectedCity;
  ApiServerMode _serverMode = ApiServerMode.deployed;
  String? _activeServerUrl;

  String get _selectedRole {
    return _portalType == _PortalType.customer ? 'USER' : 'PROVIDER';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadServerModeConfig();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _resetScrollPosition(jump: true);
        // A second reset prevents stale Android focus/viewport restore
        // from reopening the form in the middle.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _resetScrollPosition(jump: true);
          }
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _resetScrollPosition(jump: true);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _experienceController.dispose();
    _skillsController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isProviderRegistration = !_isLogin && _portalType == _PortalType.provider;

    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        (!_isLogin && _nameController.text.trim().isEmpty)) {
      _showMessage('Please fill all required fields');
      return;
    }

    if (isProviderRegistration) {
      final isProviderFormValid =
          _providerRegistrationFormKey.currentState?.validate() ?? false;
      if (!isProviderFormValid) {
        _showMessage('Please fix the highlighted provider fields.');
        return;
      }
    }

    final normalizedContact = isProviderRegistration
        ? IndiaLocationData.digitsOnly(_contactController.text)
        : null;
    final normalizedAddress =
        isProviderRegistration ? _addressController.text.trim() : null;
    final normalizedCity =
        isProviderRegistration ? (_selectedCity ?? '').trim() : null;
    final normalizedState =
        isProviderRegistration ? (_selectedState ?? '').trim() : null;
    final normalizedPincode =
        isProviderRegistration ? _pincodeController.text.trim() : null;

    if (isProviderRegistration &&
        (normalizedContact == null ||
            normalizedAddress == null ||
            normalizedCity == null ||
            normalizedState == null ||
            normalizedPincode == null ||
            normalizedContact.isEmpty ||
            normalizedAddress.isEmpty ||
            normalizedCity.isEmpty ||
            normalizedState.isEmpty ||
            normalizedPincode.isEmpty)) {
      _showMessage('Provider registration needs complete location and contact details.');
      return;
    }

    if (isProviderRegistration) {
      _contactController.text = normalizedContact!;
      _stateController.text = normalizedState!;
      _cityController.text = normalizedCity!;
      _pincodeController.text = normalizedPincode!;
    }

    int? experienceYears;
    if (_experienceController.text.trim().isNotEmpty) {
      experienceYears = int.tryParse(_experienceController.text.trim());
      if (experienceYears == null || experienceYears < 0 || experienceYears > 60) {
        _showMessage('Experience must be between 0 and 60 years.');
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authResponse = _isLogin
          ? await ApiService.login(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            )
          : await ApiService.register(
              name: _nameController.text.trim(),
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
              role: _selectedRole,
              contactNumber: isProviderRegistration
                ? normalizedContact
                : null,
              address: isProviderRegistration
                ? normalizedAddress
                : null,
              city: isProviderRegistration ? normalizedCity : null,
              state: isProviderRegistration ? normalizedState : null,
              pincode: isProviderRegistration
                ? normalizedPincode
                : null,
              experienceYears: isProviderRegistration ? experienceYears : null,
              skills: isProviderRegistration
                ? _skillsController.text.trim()
                : null,
              bio: isProviderRegistration ? _bioController.text.trim() : null,
            );

      if (!_isLogin && isProviderRegistration && _selectedProfileImageBytes != null) {
        await ApiService.uploadProfileImage(
          userId: authResponse.userId,
          fileBytes: _selectedProfileImageBytes!,
          fileName: _selectedProfileImageName ?? 'provider_profile.jpg',
        );
      }

      if (_isLogin && authResponse.role != _selectedRole) {
        final expectedPortal =
            authResponse.role == 'PROVIDER' ? 'Provider' : 'Customer';
        _showMessage('Use the $expectedPortal section for this account.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('userId', authResponse.userId);
      await prefs.setString('userName', authResponse.name);
      await prefs.setString('userRole', authResponse.role);

      if (!mounted) return;
      if (authResponse.role == 'PROVIDER') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProviderDashboardScreen(
              userId: authResponse.userId,
              userName: authResponse.name,
            ),
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ServiceListScreen(
            userId: authResponse.userId,
            userName: authResponse.name,
          ),
        ),
      );
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _resetScrollPosition({bool jump = false}) {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!_scrollController.hasClients) {
      return;
    }

    final targetOffset = _scrollController.position.minScrollExtent;

    if (jump) {
      _scrollController.jumpTo(targetOffset);
      return;
    }

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
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

  Future<void> _pickProviderImage() async {
    try {
      final source = await _selectImageSource();
      if (source == null) {
        return;
      }

      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1400,
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
      });
    } catch (_) {
      _showMessage('Unable to pick image. Please check camera/media permissions.');
    }
  }

  List<String> get _availableStates => IndiaLocationData.states;

  List<String> get _availableCities {
    return IndiaLocationData.citiesForState(_selectedState);
  }

  void _onStateSelected(String? state) {
    setState(() {
      _selectedState = state;
      _stateController.text = state ?? '';
      _selectedCity = null;
      _cityController.clear();
    });
  }

  void _onCitySelected(String? city) {
    setState(() {
      _selectedCity = city;
      _cityController.text = city ?? '';
    });
  }

  Future<String?> _showSearchableOptionPicker({
    required String title,
    required List<String> options,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        String query = '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = options
                .where((item) => item.toLowerCase().contains(query.toLowerCase()))
                .toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.72,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                        child: TextField(
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Search $title',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: query.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      setModalState(() {
                                        query = '';
                                      });
                                    },
                                    icon: const Icon(Icons.clear_rounded),
                                  ),
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              query = value.trim();
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No results found',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  return ListTile(
                                    title: Text(item),
                                    onTap: () => Navigator.pop(sheetContext, item),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickStateFromSearch() async {
    if (_isLoading) {
      return;
    }

    final selected = await _showSearchableOptionPicker(
      title: 'state',
      options: _availableStates,
    );

    if (!mounted || selected == null) {
      return;
    }

    _onStateSelected(selected);
    _providerRegistrationFormKey.currentState?.validate();
  }

  Future<void> _pickCityFromSearch() async {
    if (_isLoading) {
      return;
    }

    if (_selectedState == null) {
      _showMessage('Please select a state first.');
      return;
    }

    final selected = await _showSearchableOptionPicker(
      title: 'city',
      options: _availableCities,
    );

    if (!mounted || selected == null) {
      return;
    }

    _onCitySelected(selected);
    _providerRegistrationFormKey.currentState?.validate();
  }

  String? _validateProviderPhone(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Contact number is required';
    }

    if (!IndiaLocationData.isValidIndianPhone(text)) {
      return 'Enter a valid 10-digit Indian mobile number';
    }

    return null;
  }

  String? _validateProviderAddress(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Address is required';
    }

    if (text.length < 10) {
      return 'Address should be at least 10 characters';
    }

    return null;
  }

  String? _validateProviderState(String? value) {
    final state = (value ?? '').trim();
    if (state.isEmpty) {
      return 'Please select a state';
    }

    if (!IndiaLocationData.stateExists(state)) {
      return 'Please select a valid state';
    }

    return null;
  }

  String? _validateProviderCity(String? value) {
    final city = (value ?? '').trim();
    if (city.isEmpty) {
      return 'Please select a city';
    }

    final state = (_selectedState ?? '').trim();
    if (state.isEmpty) {
      return 'Select a state first';
    }

    if (!IndiaLocationData.cityBelongsToState(state: state, city: city)) {
      return 'Please select a valid city for the selected state';
    }

    return null;
  }

  String? _validateProviderPincode(String? value) {
    final pincode = (value ?? '').trim();
    if (pincode.isEmpty) {
      return 'Pincode is required';
    }

    if (!IndiaLocationData.isValidIndianPincode(pincode)) {
      return 'Enter a valid 6-digit pincode';
    }

    final state = (_selectedState ?? '').trim();
    if (state.isNotEmpty &&
        !IndiaLocationData.isPincodeCompatibleWithState(
          state: state,
          pincode: pincode,
        )) {
      return 'Pincode does not match the selected state';
    }

    return null;
  }

  String? _validateProviderExperience(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return null;
    }

    final years = int.tryParse(text);
    if (years == null || years < 0 || years > 60) {
      return 'Experience must be between 0 and 60 years';
    }

    return null;
  }

  String? _validateProviderSkills(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return null;
    }

    if (text.length < 2) {
      return 'Enter at least one valid skill';
    }

    return null;
  }

  String? _validateProviderBio(String? value) {
    final text = (value ?? '').trim();
    if (text.length > 300) {
      return 'Bio should be at most 300 characters';
    }

    return null;
  }

  String _headlineText() {
    if (_portalType == _PortalType.provider) {
      return _isLogin ? 'Welcome to Servico' : 'Register on Servico';
    }
    return _isLogin ? 'Welcome to Servico' : 'Register on Servico';
  }

  String _descriptionText() {
    if (_portalType == _PortalType.provider) {
      return _isLogin
          ? 'Provider login: manage your services, reviews, and live orders.'
          : 'Create your provider account on Servico and publish local services.';
    }
    return _isLogin
        ? 'Sign in to book trusted local professionals in minutes.'
        : 'Create your Servico account to discover and book nearby experts.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.brand,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.room_service_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Welcome to Servico',
                                style:
                                    Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.cloud_outlined),
                          title: Text('Server: ${serverModeLabel(_serverMode)}'),
                          subtitle: Text(_activeServerUrl ?? 'Loading...'),
                          trailing: TextButton(
                            onPressed: _changeServerMode,
                            child: const Text('Change'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildPortalSelector(context),
                        const SizedBox(height: 14),
                        Text(
                          _headlineText(),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _descriptionText(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                        _buildModeSelector(context),
                        const SizedBox(height: 18),
                        if (_isLoading) ...[
                          const LinearProgressIndicator(minHeight: 3),
                          const SizedBox(height: 8),
                          Text(
                            _isLogin
                                ? 'Signing in...'
                                : 'Creating your account...',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (!_isLogin) ...[
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (!_isLogin &&
                            _portalType == _PortalType.provider)
                          _buildProviderRegistrationFields(),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon:
                                Icon(Icons.alternate_email_rounded),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline_rounded),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _isLogin
                                        ? 'Sign In'
                                        : 'Create Account',
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _isLogin = !_isLogin;
                                    });
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (mounted) {
                                        _resetScrollPosition(jump: true);
                                      }
                                    });
                                  },
                            child: Text(
                              _isLogin
                                  ? 'New here? Switch to register'
                                  : 'Already registered? Switch to login',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortalSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Portal',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.brand.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _ModeButton(
                  title: 'Customer',
                  selected: _portalType == _PortalType.customer,
                  onTap: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _portalType = _PortalType.customer;
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              _resetScrollPosition(jump: true);
                            }
                          });
                        },
                ),
              ),
              Expanded(
                child: _ModeButton(
                  title: 'Provider',
                  selected: _portalType == _PortalType.provider,
                  onTap: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _portalType = _PortalType.provider;
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              _resetScrollPosition(jump: true);
                            }
                          });
                        },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              title: 'Login',
              selected: _isLogin,
              onTap: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _isLogin = true;
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _resetScrollPosition(jump: true);
                        }
                      });
                    },
            ),
          ),
          Expanded(
            child: _ModeButton(
              title: 'Register',
              selected: !_isLogin,
              onTap: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _isLogin = false;
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _resetScrollPosition(jump: true);
                        }
                      });
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderRegistrationFields() {
    return Form(
      key: _providerRegistrationFormKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        children: [
          const SizedBox(height: 8),
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
                  'Primary Contact',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'This information is visible to customers while booking.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _contactController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Contact Number *',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: _validateProviderPhone,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Address *',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                  validator: _validateProviderAddress,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                  'Service Area',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'City options depend on the selected state.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _stateController,
                  readOnly: true,
                  onTap: _pickStateFromSearch,
                  decoration: const InputDecoration(
                    labelText: 'State *',
                    prefixIcon: Icon(Icons.map_outlined),
                    suffixIcon: Icon(Icons.search_rounded),
                  ),
                  validator: _validateProviderState,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _cityController,
                  readOnly: true,
                  onTap: _selectedState == null ? null : _pickCityFromSearch,
                  decoration: InputDecoration(
                    labelText: 'City *',
                    prefixIcon: const Icon(Icons.location_city_outlined),
                    suffixIcon: const Icon(Icons.search_rounded),
                    hintText: _selectedState == null
                        ? 'Select state first'
                        : null,
                  ),
                  validator: _validateProviderCity,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _pincodeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Pincode *',
                    prefixIcon: Icon(Icons.pin_drop_outlined),
                  ),
                  validator: _validateProviderPincode,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _experienceController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            decoration: const InputDecoration(
              labelText: 'Experience (years)',
              prefixIcon: Icon(Icons.work_history_outlined),
            ),
            validator: _validateProviderExperience,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _skillsController,
            decoration: const InputDecoration(
              labelText: 'Skills (comma separated)',
              prefixIcon: Icon(Icons.handyman_outlined),
            ),
            validator: _validateProviderSkills,
          ),
          const SizedBox(height: 12),
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
                  'Profile Image (direct upload)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFE7F0EE),
                      ),
                      clipBehavior: Clip.antiAlias,
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
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _pickProviderImage,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Choose'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _bioController,
            maxLines: 3,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Professional Bio',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
            validator: _validateProviderBio,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback? onTap;

  const _ModeButton({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}