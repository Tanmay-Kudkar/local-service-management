import 'package:flutter/material.dart';
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

  bool _isLogin = true;
  bool _isLoading = false;
  bool _showContent = false;
  _PortalType _portalType = _PortalType.customer;

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
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        (!_isLogin && _nameController.text.trim().isEmpty)) {
      _showMessage('Please fill all required fields');
      return;
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
            );

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

  String _headlineText() {
    if (_portalType == _PortalType.provider) {
      return _isLogin ? 'Provider Sign In' : 'Create Provider Account';
    }
    return _isLogin ? 'Welcome Back' : 'Create Your Account';
  }

  String _descriptionText() {
    if (_portalType == _PortalType.provider) {
      return _isLogin
          ? 'Sign in to manage your services and bookings.'
          : 'Create a provider account to publish services for customers.';
    }
    return _isLogin
        ? 'Sign in to book trusted local professionals.'
        : 'Register once to book plumbers and electricians in minutes.';
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
                                    'Local Service App',
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