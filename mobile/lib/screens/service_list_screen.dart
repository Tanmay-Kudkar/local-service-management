import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/service_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/server_warmup_loading.dart';
import 'auth_screen.dart';
import 'booking_screen.dart';

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
  String _displayName = '';
  int _loadRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    _displayName = widget.userName.trim();
    _loadServices();
    _loadUserProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _showContent = true;
      });
    });
  }

  Future<void> _loadServices() async {
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
      final services = await ApiService.getServices();
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

  Future<void> _loadUserProfile() async {
    try {
      final profile = await ApiService.getUserProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        _displayName = profile.name;
      });
    } catch (_) {
      // Keep existing display name if profile fetch fails.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadServices,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 170,
                  pinned: true,
                  floating: false,
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        child: IconButton(
                          tooltip: 'Logout',
                          onPressed: _logout,
                          icon: const Icon(Icons.logout_rounded, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    title: const Text(
                      'Available Services',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    background: Container(
                      margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.brand.withValues(alpha: 0.96),
                            const Color(0xFF184B46),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Hello, ${_displayName.isEmpty ? 'User' : _displayName}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Book trusted local experts in seconds.',
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
                              onBook: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BookingScreen(
                                      userId: widget.userId,
                                      service: service,
                                    ),
                                  ),
                                );
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

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onBook,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Hero(
                tag: 'service-icon-${service.id}',
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(meta.icon, color: meta.color),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
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
                        Text(
                          'From Rs ${service.price.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayHint,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (service.providerName != null && service.providerName!.trim().isNotEmpty) ...[
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
                              color: const Color(0xFFECF7F4),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              service.providerVerified
                                  ? 'Provider: ${service.providerName} (Verified)'
                                  : 'Provider: ${service.providerName}',
                              style: const TextStyle(
                                color: Color(0xFF0E6F67),
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
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: onBook,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(76, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Book'),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: onProviderDetails,
                    child: const Text('Provider'),
                  ),
                ],
              ),
            ],
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

class _ProviderDetailsSheet extends StatelessWidget {
  final ServiceModel service;

  const _ProviderDetailsSheet({required this.service});

  @override
  Widget build(BuildContext context) {
    final providerName = service.providerName ?? 'Provider';
    final providerCity = service.providerCity?.trim() ?? '';
    final providerState = service.providerState?.trim() ?? '';
    final providerAddress = service.providerAddress?.trim() ?? '';
    final providerContact = service.providerContactNumber?.trim() ?? '';
    final providerSkills = service.providerSkills?.trim() ?? '';
    final providerBio = service.providerBio?.trim() ?? '';

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
                    backgroundImage: service.providerProfileImageUrl != null
                            && service.providerProfileImageUrl!.trim().isNotEmpty
                        ? NetworkImage(service.providerProfileImageUrl!)
                        : null,
                    child: service.providerProfileImageUrl == null
                            || service.providerProfileImageUrl!.trim().isEmpty
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
                ],
              ),
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