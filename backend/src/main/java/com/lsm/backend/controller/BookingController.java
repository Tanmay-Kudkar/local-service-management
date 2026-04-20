package com.lsm.backend.controller;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.lsm.backend.dto.BookingStatusUpdateRequest;
import com.lsm.backend.dto.BookingTrackingResponse;
import com.lsm.backend.dto.BookingRequest;
import com.lsm.backend.service.BookingService;

@RestController
@RequestMapping("/bookings")
public class BookingController {

    private final BookingService bookingService;

    public BookingController(BookingService bookingService) {
        this.bookingService = bookingService;
    }

    @PostMapping
    public ResponseEntity<BookingTrackingResponse> createBooking(@RequestBody BookingRequest request) {
        return ResponseEntity.ok(bookingService.createBooking(request));
    }

    @GetMapping("/{userId}")
    public ResponseEntity<List<BookingTrackingResponse>> getBookingsByUserId(@PathVariable Long userId) {
        return ResponseEntity.ok(bookingService.getBookingsByUserId(userId));
    }

    @GetMapping("/provider/{providerId}")
    public ResponseEntity<List<BookingTrackingResponse>> getBookingsByProviderId(@PathVariable Long providerId) {
        return ResponseEntity.ok(bookingService.getBookingsByProviderId(providerId));
    }

    @PutMapping("/{bookingId}/provider-status")
    public ResponseEntity<BookingTrackingResponse> updateBookingStatusByProvider(
            @PathVariable Long bookingId,
            @RequestBody BookingStatusUpdateRequest request) {
        return ResponseEntity.ok(bookingService.updateBookingStatusByProvider(bookingId, request));
    }
}