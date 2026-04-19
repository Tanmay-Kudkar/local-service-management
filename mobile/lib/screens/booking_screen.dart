import 'package:flutter/material.dart';

import '../models/booking_model.dart';
import '../models/service_model.dart';
import '../services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadBookings();
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
      final bookings = await ApiService.getBookingsByUserId(widget.userId);
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Book Service')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.service.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('Price: Rs ${widget.service.price.toStringAsFixed(0)}'),
            const SizedBox(height: 20),
            Text('Selected Date: ${_formatDate(_selectedDate)}'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _pickDate,
              child: const Text('Choose Date'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isBooking ? null : _bookNow,
                child: _isBooking
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirm Booking'),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Your Bookings', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoadingBookings
                  ? const Center(child: CircularProgressIndicator())
                  : _bookings.isEmpty
                      ? const Center(child: Text('No bookings yet'))
                      : ListView.builder(
                          itemCount: _bookings.length,
                          itemBuilder: (context, index) {
                            final booking = _bookings[index];
                            return Card(
                              child: ListTile(
                                title: Text('Service ID: ${booking.serviceId}'),
                                subtitle: Text('Date: ${booking.date}'),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}