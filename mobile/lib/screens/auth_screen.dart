import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import 'provider_dashboard_screen.dart';
import 'service_list_screen.dart';

enum _PortalType { customer, provider }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
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
  final _imagePicker = ImagePicker();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _showContent = false;
  _PortalType _portalType = _PortalType.customer;
  Uint8List? _selectedProfileImageBytes;
  String? _selectedProfileImageName;

  String get _selectedRole {
    return _portalType == _PortalType.customer ? 'USER' : 'PROVIDER';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _showContent = true;
      });
    });
  }

  @override
  void dispose() {
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

    if (isProviderRegistration &&
        (_contactController.text.trim().isEmpty ||
            _addressController.text.trim().isEmpty ||
            _cityController.text.trim().isEmpty)) {
      _showMessage('Provider registration needs contact number, address and city.');
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
                ? _contactController.text.trim()
                : null,
              address: isProviderRegistration
                ? _addressController.text.trim()
                : null,
              city: isProviderRegistration ? _cityController.text.trim() : null,
              state: isProviderRegistration ? _stateController.text.trim() : null,
              pincode: isProviderRegistration
                ? _pincodeController.text.trim()
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
        Navigator.pushReplacement(
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

      Navigator.pushReplacement(
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickProviderImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
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
      _showMessage('Unable to pick image from gallery.');
    }
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                offset: _showContent ? Offset.zero : const Offset(0, 0.08),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: _showContent ? 1 : 0,
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
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: !_isLogin
                                  ? Padding(
                                      key: const ValueKey('nameField'),
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: TextField(
                                        controller: _nameController,
                                        decoration: const InputDecoration(
                                          labelText: 'Full Name',
                                          prefixIcon: Icon(Icons.person_outline),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('nameHidden'),
                                    ),
                            ),
                            if (!_isLogin && _portalType == _PortalType.provider)
                              _buildProviderRegistrationFields(),
                            TextField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon: Icon(Icons.alternate_email_rounded),
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
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderRegistrationFields() {
    return Column(
      children: [
        const SizedBox(height: 8),
        TextField(
          controller: _contactController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Contact Number *',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Address *',
            prefixIcon: Icon(Icons.home_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cityController,
          decoration: const InputDecoration(
            labelText: 'City *',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 12),
        TextField(
          controller: _experienceController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Experience (years)',
            prefixIcon: Icon(Icons.work_history_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _skillsController,
          decoration: const InputDecoration(
            labelText: 'Skills (comma separated)',
            prefixIcon: Icon(Icons.handyman_outlined),
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
        TextField(
          controller: _bioController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Professional Bio',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
        const SizedBox(height: 4),
      ],
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