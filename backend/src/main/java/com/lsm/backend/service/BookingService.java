package com.lsm.backend.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import com.lsm.backend.dto.BookingStatusUpdateRequest;
import com.lsm.backend.dto.BookingTrackingResponse;
import com.lsm.backend.dto.BookingRequest;
import com.lsm.backend.entity.Booking;
import com.lsm.backend.entity.BookingStatus;
import com.lsm.backend.entity.Role;
import com.lsm.backend.entity.ServiceEntity;
import com.lsm.backend.entity.User;
import com.lsm.backend.exception.BadRequestException;
import com.lsm.backend.repository.BookingRepository;
import com.lsm.backend.repository.ReviewRepository;
import com.lsm.backend.repository.ServiceEntityRepository;
import com.lsm.backend.repository.UserRepository;

@Service
public class BookingService {

    private static final List<BookingStatus> ACTIVE_BOOKING_STATUSES = List.of(
            BookingStatus.PENDING,
            BookingStatus.CONFIRMED,
            BookingStatus.IN_PROGRESS);

    private static final long DUPLICATE_BOOKING_COOLDOWN_MINUTES = 5;

    private final BookingRepository bookingRepository;
    private final UserRepository userRepository;
    private final ServiceEntityRepository serviceEntityRepository;
    private final ReviewRepository reviewRepository;

    public BookingService(
            BookingRepository bookingRepository,
            UserRepository userRepository,
            ServiceEntityRepository serviceEntityRepository,
            ReviewRepository reviewRepository) {
        this.bookingRepository = bookingRepository;
        this.userRepository = userRepository;
        this.serviceEntityRepository = serviceEntityRepository;
        this.reviewRepository = reviewRepository;
    }

    public BookingTrackingResponse createBooking(BookingRequest request) {
        if (request.getUserId() == null || request.getServiceId() == null || request.getDate() == null) {
            throw new BadRequestException("userId, serviceId and date are required");
        }

        if (request.getDate().isBefore(LocalDate.now())) {
            throw new BadRequestException("Booking date cannot be in the past");
        }

        if (!userRepository.existsById(request.getUserId())) {
            throw new BadRequestException("User not found");
        }

        ServiceEntity service = serviceEntityRepository.findById(request.getServiceId())
                .orElseThrow(() -> new BadRequestException("Service not found"));

        User provider = null;
        if (service.getProviderId() != null) {
            provider = userRepository.findById(service.getProviderId())
                    .orElse(null);

            boolean hasActiveBookingSameDate = bookingRepository.existsByUserIdAndProviderIdAndDateAndStatusIn(
                    request.getUserId(),
                    service.getProviderId(),
                    request.getDate(),
                    ACTIVE_BOOKING_STATUSES);
            if (hasActiveBookingSameDate) {
                throw new BadRequestException(
                        "You already have an active booking with this provider on the selected date");
            }

            LocalDateTime cooldownThreshold = LocalDateTime.now().minusMinutes(DUPLICATE_BOOKING_COOLDOWN_MINUTES);
            boolean hasRecentDuplicate = bookingRepository.existsByUserIdAndProviderIdAndCreatedAtAfter(
                    request.getUserId(),
                    service.getProviderId(),
                    cooldownThreshold);
            if (hasRecentDuplicate) {
                throw new BadRequestException("Please wait 5 minutes before booking the same provider again");
            }
        }

        Booking booking = new Booking();
        booking.setUserId(request.getUserId());
        booking.setServiceId(request.getServiceId());
        booking.setProviderId(service.getProviderId());
        booking.setDate(request.getDate());
        booking.setStatus(BookingStatus.PENDING);
        booking.setTrackingNote("Order placed");

        if (provider != null) {
            booking.setLiveLocationSharingEnabled(defaultBoolean(provider.getLiveLocationSharingEnabled()));
            booking.setProviderLatitude(provider.getLiveLatitude());
            booking.setProviderLongitude(provider.getLiveLongitude());
            booking.setProviderLocationUpdatedAt(provider.getLiveLocationUpdatedAt());
        }

        Booking saved = bookingRepository.save(booking);
        return toResponse(saved, service, provider, false);
    }

    public List<BookingTrackingResponse> getBookingsByUserId(Long userId) {
        return getBookingsByUserId(userId, null);
    }

    public List<BookingTrackingResponse> getBookingsByUserId(Long userId, Long providerId) {
        if (!userRepository.existsById(userId)) {
            throw new BadRequestException("User not found");
        }

        List<Booking> bookings = providerId == null
                ? bookingRepository.findByUserIdOrderByCreatedAtDesc(userId)
                : bookingRepository.findByUserIdAndProviderIdOrderByCreatedAtDesc(userId, providerId);
        return mapBookings(bookings);
    }

    public List<BookingTrackingResponse> getBookingsByProviderId(Long providerId) {
        User provider = userRepository.findById(providerId)
                .orElseThrow(() -> new BadRequestException("Provider not found"));

        if (provider.getRole() != Role.PROVIDER) {
            throw new BadRequestException("Only PROVIDER accounts can access provider bookings");
        }

        List<Booking> bookings = bookingRepository.findByProviderIdOrderByCreatedAtDesc(providerId);
        return mapBookings(bookings);
    }

    public BookingTrackingResponse updateBookingStatusByProvider(Long bookingId, BookingStatusUpdateRequest request) {
        if (request == null || request.getProviderId() == null || request.getStatus() == null) {
            throw new BadRequestException("providerId and status are required");
        }

        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new BadRequestException("Booking not found"));

        if (booking.getProviderId() == null || !booking.getProviderId().equals(request.getProviderId())) {
            throw new BadRequestException("You can only update your own bookings");
        }

        BookingStatus status = parseStatus(request.getStatus());
        booking.setStatus(status);

        String note = normalizeNullableText(request.getTrackingNote());
        if (note == null) {
            note = defaultTrackingNote(status);
        }
        booking.setTrackingNote(note);

        Booking saved = bookingRepository.save(booking);

        ServiceEntity service = serviceEntityRepository.findById(saved.getServiceId())
                .orElse(null);
        User provider = userRepository.findById(saved.getProviderId())
                .orElse(null);
        boolean reviewSubmitted = reviewRepository.existsByBookingId(saved.getId());

        return toResponse(saved, service, provider, reviewSubmitted);
    }

    private List<BookingTrackingResponse> mapBookings(List<Booking> bookings) {
        if (bookings.isEmpty()) {
            return List.of();
        }

        Set<Long> serviceIds = bookings.stream()
                .map(Booking::getServiceId)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());

        Set<Long> providerIds = bookings.stream()
                .map(Booking::getProviderId)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());

        Set<Long> bookingIds = bookings.stream()
                .map(Booking::getId)
                .collect(Collectors.toSet());

        Map<Long, ServiceEntity> servicesById = serviceEntityRepository.findAllById(serviceIds).stream()
                .collect(Collectors.toMap(ServiceEntity::getId, service -> service));

        Map<Long, User> providersById = userRepository.findAllById(providerIds).stream()
                .collect(Collectors.toMap(User::getId, provider -> provider));

        Set<Long> reviewedBookingIds = reviewRepository.findByBookingIdIn(bookingIds).stream()
                .map(review -> review.getBookingId())
                .collect(Collectors.toSet());

        return bookings.stream()
                .map(booking -> toResponse(
                        booking,
                        servicesById.get(booking.getServiceId()),
                        providersById.get(booking.getProviderId()),
                        reviewedBookingIds.contains(booking.getId())))
                .toList();
    }

    private BookingTrackingResponse toResponse(
            Booking booking,
            ServiceEntity service,
            User provider,
            boolean reviewSubmitted) {
        BookingStatus status = booking.getStatus() == null ? BookingStatus.PENDING : booking.getStatus();

        Boolean liveSharing = provider != null
                ? defaultBoolean(provider.getLiveLocationSharingEnabled())
                : defaultBoolean(booking.getLiveLocationSharingEnabled());
        Double liveLatitude = provider != null ? provider.getLiveLatitude() : booking.getProviderLatitude();
        Double liveLongitude = provider != null ? provider.getLiveLongitude() : booking.getProviderLongitude();
        String liveLocationUpdatedAt = provider != null && provider.getLiveLocationUpdatedAt() != null
                ? provider.getLiveLocationUpdatedAt().toString()
                : booking.getProviderLocationUpdatedAt() == null ? null
                        : booking.getProviderLocationUpdatedAt().toString();

        return new BookingTrackingResponse(
                booking.getId(),
                booking.getUserId(),
                booking.getServiceId(),
                service == null ? null : service.getName(),
                service == null ? null : service.getPrice(),
                booking.getProviderId(),
                provider == null ? null : provider.getName(),
                booking.getDate(),
                status.name(),
                booking.getTrackingNote(),
                liveSharing,
                liveLatitude,
                liveLongitude,
                liveLocationUpdatedAt,
                booking.getCreatedAt() == null ? null : booking.getCreatedAt().toString(),
                booking.getUpdatedAt() == null ? null : booking.getUpdatedAt().toString(),
                reviewSubmitted);
    }

    private BookingStatus parseStatus(String rawStatus) {
        try {
            return BookingStatus.valueOf(rawStatus.trim().toUpperCase());
        } catch (Exception ex) {
            throw new BadRequestException(
                    "Invalid status. Allowed: PENDING, CONFIRMED, IN_PROGRESS, COMPLETED, CANCELLED");
        }
    }

    private String defaultTrackingNote(BookingStatus status) {
        return switch (status) {
            case PENDING -> "Order placed";
            case CONFIRMED -> "Provider accepted the order";
            case IN_PROGRESS -> "Provider is on the way";
            case COMPLETED -> "Service completed";
            case CANCELLED -> "Order cancelled";
        };
    }

    private String normalizeNullableText(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private boolean defaultBoolean(Boolean value) {
        return value != null && value;
    }
}