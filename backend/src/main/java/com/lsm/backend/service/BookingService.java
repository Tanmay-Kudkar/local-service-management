package com.lsm.backend.service;

import java.util.List;

import org.springframework.stereotype.Service;

import com.lsm.backend.dto.BookingRequest;
import com.lsm.backend.entity.Booking;
import com.lsm.backend.exception.BadRequestException;
import com.lsm.backend.repository.BookingRepository;
import com.lsm.backend.repository.ServiceEntityRepository;
import com.lsm.backend.repository.UserRepository;

@Service
public class BookingService {

    private final BookingRepository bookingRepository;
    private final UserRepository userRepository;
    private final ServiceEntityRepository serviceEntityRepository;

    public BookingService(
            BookingRepository bookingRepository,
            UserRepository userRepository,
            ServiceEntityRepository serviceEntityRepository) {
        this.bookingRepository = bookingRepository;
        this.userRepository = userRepository;
        this.serviceEntityRepository = serviceEntityRepository;
    }

    public Booking createBooking(BookingRequest request) {
        if (request.getUserId() == null || request.getServiceId() == null || request.getDate() == null) {
            throw new BadRequestException("userId, serviceId and date are required");
        }

        if (!userRepository.existsById(request.getUserId())) {
            throw new BadRequestException("User not found");
        }

        if (!serviceEntityRepository.existsById(request.getServiceId())) {
            throw new BadRequestException("Service not found");
        }

        Booking booking = new Booking();
        booking.setUserId(request.getUserId());
        booking.setServiceId(request.getServiceId());
        booking.setDate(request.getDate());

        return bookingRepository.save(booking);
    }

    public List<Booking> getBookingsByUserId(Long userId) {
        if (!userRepository.existsById(userId)) {
            throw new BadRequestException("User not found");
        }

        return bookingRepository.findByUserId(userId);
    }
}