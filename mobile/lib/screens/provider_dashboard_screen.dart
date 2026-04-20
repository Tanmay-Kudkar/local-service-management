import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/service_model.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import 'auth_screen.dart';

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

  final _customNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  int? _editingServiceId;
  int? _deletingServiceId;
  List<ServiceModel> _myServices = [];
  List<String> _serviceTypes = [];
  String _displayName = '';
  String? _selectedServiceType;

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
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        ApiService.getProviderServices(widget.userId),
        ApiService.getUserProfile(widget.userId),
        ApiService.getServiceTypes(),
      ]);

      final services = results[0] as List<ServiceModel>;
      final profile = results[1] as UserProfile;
      final serviceTypes = _normalizeServiceTypes(results[2] as List<String>);

      if (!mounted) return;
      setState(() {
        _myServices = services;
        _displayName = profile.name;
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

  List<String> _normalizeServiceTypes(List<String> rawTypes) {
    final normalized = rawTypes
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return normalized;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadDashboardData,
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
                      'Provider Dashboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    background: Container(
                      margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0E6F67), Color(0xFF184B46)],
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
                              'Hello, ${_displayName.isEmpty ? 'Provider' : _displayName}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Add and manage services visible to customers.',
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _editingServiceId == null
                                  ? 'Publish New Service'
                                  : 'Update Service',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              key: ValueKey<String?>(_selectedServiceType),
                              initialValue: _selectedServiceType,
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
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Text(
                      _isLoading
                          ? 'Loading your services...'
                          : '${_myServices.length} services published',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                if (_isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_myServices.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ProviderEmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.builder(
                      itemCount: _myServices.length,
                      itemBuilder: (context, index) {
                        final service = _myServices[index];
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
                              trailing: SizedBox(
                                width: 96,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Edit Service',
                                      onPressed: _isSaving || _deletingServiceId != null
                                          ? null
                                          : () => _startEditing(service),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete Service',
                                      onPressed: _isSaving
                                          ? null
                                          : () => _deleteService(service),
                                      icon: _deletingServiceId == service.id
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
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

class _ProviderEmptyState extends StatelessWidget {
  const _ProviderEmptyState();

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
                  'No services published yet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Use the form above to publish your first service.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}