import 'dart:async';

import 'package:flutter/material.dart';

import '../models/booking_model.dart';
import '../models/service_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/server_warmup_loading.dart';

class MyBookingsScreen extends StatefulWidget {
  final int userId;

  const MyBookingsScreen({
    super.key,
    required this.userId,
  });

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  bool _isLoadingBookings = false;
  bool _showWarmupHint = false;
  List<BookingModel> _bookings = [];
  Map<int, ServiceModel> _serviceLookup = {};
  int _loadRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    final requestVersion = ++_loadRequestVersion;
    setState(() {
      _isLoadingBookings = true;
      _showWarmupHint = false;
    });

    Timer(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      if (_isLoadingBookings && requestVersion == _loadRequestVersion) {
        setState(() {
          _showWarmupHint = true;
        });
      }
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
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isEmpty ? 'Could not load bookings' : message,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBookings = false;
        });
      }
    }
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

  bool _canSubmitReview(BookingModel booking) {
    return booking.status == 'COMPLETED' && !booking.reviewSubmitted;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openReviewDialog(BookingModel booking) async {
    int selectedRating = 5;
    final commentController = TextEditingController();
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Rate Your Service'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.serviceName ?? 'Service #${booking.serviceId}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'How was your experience?',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final rating = index + 1;
                        return IconButton(
                          onPressed: isSubmitting
                              ? null
                              : () {
                                  setDialogState(() {
                                    selectedRating = rating;
                                  });
                                },
                          icon: Icon(
                            rating <= selectedRating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: const Color(0xFFF4B400),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      maxLength: 250,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Comment (optional)',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.rate_review_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final navigator = Navigator.of(dialogContext);
                          setDialogState(() {
                            isSubmitting = true;
                          });

                          try {
                            await ApiService.createReview(
                              bookingId: booking.id,
                              userId: widget.userId,
                              rating: selectedRating,
                              comment: commentController.text.trim(),
                            );

                            if (!mounted) {
                              return;
                            }

                            navigator.pop();
                            _showMessage('Thanks for your feedback. Review submitted.');
                            await _loadBookings();
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                            });
                            _showMessage(e.toString().replaceFirst('Exception: ', ''));
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit Review'),
                ),
              ],
            );
          },
        );
      },
    );

    commentController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: const Color(0xFFF2F7F4),
        foregroundColor: AppTheme.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadBookings,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                if (_isLoadingBookings)
                  ...[
                    ServerWarmupBanner(
                      showWarmupMessage: _showWarmupHint,
                      title: 'Loading booking history',
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(
                      3,
                      (_) => const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: BookingHistorySkeletonTile(),
                      ),
                    ),
                  ]
                else if (_bookings.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.history_toggle_off_rounded,
                            size: 40,
                            color: AppTheme.textSecondary.withValues(alpha: 0.7),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No bookings yet',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Book a service from the customer home screen to see history here.',
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
                    final meta = _myBookingServiceMeta(serviceName);

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
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor:
                                          meta.color.withValues(alpha: 0.14),
                                      foregroundColor: meta.color,
                                      child: Icon(meta.icon),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            serviceName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text('Date: ${booking.date}'),
                                          if (booking.providerName != null &&
                                              booking.providerName!
                                                  .trim()
                                                  .isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 2),
                                              child: Text(
                                                'Provider: ${booking.providerName}',
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statusColor(booking.status)
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(999),
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
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: meta.color.withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(999),
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
                                    if (booking.reviewSubmitted)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDDF3EE),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: const Text(
                                          'Review submitted',
                                          style: TextStyle(
                                            color: Color(0xFF0E6F67),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (booking.trackingNote != null &&
                                    booking.trackingNote!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0F4F7),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Tracking: ${booking.trackingNote}',
                                      style: const TextStyle(
                                        color: Color(0xFF335066),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                                if (_canSubmitReview(booking)) ...[
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _openReviewDialog(booking),
                                      icon: const Icon(Icons.star_rate_rounded),
                                      label: const Text('Rate Service'),
                                    ),
                                  ),
                                ],
                              ],
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

class _MyBookingServiceMeta {
  final IconData icon;
  final Color color;
  final String badge;

  const _MyBookingServiceMeta({
    required this.icon,
    required this.color,
    required this.badge,
  });
}

_MyBookingServiceMeta _myBookingServiceMeta(String serviceName) {
  final key = serviceName.toLowerCase();

  if (key == 'plumber') {
    return const _MyBookingServiceMeta(
      icon: Icons.plumbing_rounded,
      color: Color(0xFF0E6F67),
      badge: 'Water & Pipe',
    );
  }

  if (key == 'electrician') {
    return const _MyBookingServiceMeta(
      icon: Icons.electrical_services_rounded,
      color: Color(0xFFCC8B24),
      badge: 'Power & Wiring',
    );
  }

  return const _MyBookingServiceMeta(
    icon: Icons.miscellaneous_services_rounded,
    color: Color(0xFF607D8B),
    badge: 'General',
  );
}
