import 'package:flutter/material.dart';

import '../models/booking_model.dart';
import '../models/service_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';

class BookingScreen extends StatefulWidget {
  final int userId;
  final ServiceModel service;

  const BookingScreen({
    super.key,
    required this.userId,
    required this.service,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isBooking = false;
  bool _isLoadingBookings = false;
  List<BookingModel> _bookings = [];
  Map<int, ServiceModel> _serviceLookup = {};
  bool _showContent = false;

  @override
  void initState() {
    super.initState();
    _loadBookings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _showContent = true;
      });
    });
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _bookNow() async {
    setState(() {
      _isBooking = true;
    });

    try {
      await ApiService.createBooking(
        userId: widget.userId,
        serviceId: widget.service.id,
        date: _selectedDate,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking successful')), 
      );
      await _loadBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBooking = false;
        });
      }
    }
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoadingBookings = true;
    });

    try {
      final results = await Future.wait([
        ApiService.getBookingsByUserId(widget.userId),
        ApiService.getServices(),
      ]);

      final bookings = results[0] as List<BookingModel>;
      final services = results[1] as List<ServiceModel>;

      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _serviceLookup = {
          for (final service in services) service.id: service,
        };
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load bookings')), 
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBookings = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final selectedMeta = _serviceMeta(widget.service.name);

    return Scaffold(
      appBar: AppBar(title: const Text('Book Service')),
      body: AppBackground(
        child: SafeArea(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 420),
            opacity: _showContent ? 1 : 0,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Hero(
                              tag: 'service-icon-${widget.service.id}',
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: selectedMeta.color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  selectedMeta.icon,
                                  color: selectedMeta.color,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.service.name,
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                  Text(
                                    'Price: Rs ${widget.service.price.toStringAsFixed(0)}',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selectedMeta.color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      selectedMeta.badge,
                                      style: TextStyle(
                                        color: selectedMeta.color,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Selected Date: ${_formatDate(_selectedDate)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickDate,
                                icon: const Icon(Icons.event_available_rounded),
                                label: const Text('Choose Date'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isBooking ? null : _bookNow,
                                child: _isBooking
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Confirm'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    'Your Booking History',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (_isLoadingBookings)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_bookings.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.history_toggle_off_rounded,
                            size: 40,
                            color: AppTheme.textSecondary.withOpacity(0.7),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No bookings yet',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create your first booking using the form above.',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._bookings.asMap().entries.map((entry) {
                    final index = entry.key;
                    final booking = entry.value;
                    final bookedService = _serviceLookup[booking.serviceId];
                    final serviceName =
                        bookedService?.name ?? 'Service #${booking.serviceId}';
                    final meta = _serviceMeta(serviceName);

                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 260 + (index * 70)),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, (1 - value) * 10),
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: meta.color.withOpacity(0.14),
                              foregroundColor: meta.color,
                              child: Icon(meta.icon),
                            ),
                            title: Text(serviceName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 4),
                                Text('Date: ${booking.date}'),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: meta.color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    meta.badge,
                                    style: TextStyle(
                                      color: meta.color,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: const Icon(
                              Icons.verified_rounded,
                              color: AppTheme.brand,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
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

  const _ServiceMeta({
    required this.icon,
    required this.color,
    required this.badge,
  });
}

_ServiceMeta _serviceMeta(String serviceName) {
  final key = serviceName.toLowerCase();

  if (key == 'plumber') {
    return const _ServiceMeta(
      icon: Icons.plumbing_rounded,
      color: Color(0xFF0E6F67),
      badge: 'Water & Pipe',
    );
  }

  if (key == 'electrician') {
    return const _ServiceMeta(
      icon: Icons.electrical_services_rounded,
      color: Color(0xFFCC8B24),
      badge: 'Power & Wiring',
    );
  }

  return const _ServiceMeta(
    icon: Icons.miscellaneous_services_rounded,
    color: Color(0xFF607D8B),
    badge: 'General',
  );
}