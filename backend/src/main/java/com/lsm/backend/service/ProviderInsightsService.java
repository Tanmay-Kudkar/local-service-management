package com.lsm.backend.service;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import com.lsm.backend.dto.ProviderEarningsOrderItemResponse;
import com.lsm.backend.dto.ProviderEarningsResponse;
import com.lsm.backend.entity.Booking;
import com.lsm.backend.entity.BookingStatus;
import com.lsm.backend.entity.Role;
import com.lsm.backend.entity.ServiceEntity;
import com.lsm.backend.entity.User;
import com.lsm.backend.exception.BadRequestException;
import com.lsm.backend.repository.BookingRepository;
import com.lsm.backend.repository.ServiceEntityRepository;
import com.lsm.backend.repository.UserRepository;

@Service
public class ProviderInsightsService {

    private final BookingRepository bookingRepository;
    private final ServiceEntityRepository serviceEntityRepository;
    private final UserRepository userRepository;

    public ProviderInsightsService(
            BookingRepository bookingRepository,
            ServiceEntityRepository serviceEntityRepository,
            UserRepository userRepository) {
        this.bookingRepository = bookingRepository;
        this.serviceEntityRepository = serviceEntityRepository;
        this.userRepository = userRepository;
    }

    public ProviderEarningsResponse getProviderEarnings(Long providerId, LocalDate fromDate, LocalDate toDate) {
        User provider = userRepository.findById(providerId)
                .orElseThrow(() -> new BadRequestException("Provider not found"));

        if (provider.getRole() != Role.PROVIDER) {
            throw new BadRequestException("Only PROVIDER accounts can access earnings dashboard");
        }

        if (fromDate != null && toDate != null && fromDate.isAfter(toDate)) {
            throw new BadRequestException("fromDate cannot be after toDate");
        }

        List<Booking> allBookings = bookingRepository.findByProviderIdOrderByCreatedAtDesc(providerId);

        Set<Long> serviceIds = allBookings.stream()
                .map(Booking::getServiceId)
                .collect(Collectors.toSet());

        Map<Long, ServiceEntity> servicesById = serviceEntityRepository.findAllById(serviceIds).stream()
                .collect(Collectors.toMap(ServiceEntity::getId, service -> service));

        List<Booking> dateFilteredBookings = allBookings.stream()
                .filter(booking -> isWithinRange(booking.getDate(), fromDate, toDate))
                .toList();

        long pendingOrders = countByStatus(dateFilteredBookings, BookingStatus.PENDING);
        long inProgressOrders = countByStatus(dateFilteredBookings, BookingStatus.IN_PROGRESS)
                + countByStatus(dateFilteredBookings, BookingStatus.CONFIRMED);
        long completedOrders = countByStatus(dateFilteredBookings, BookingStatus.COMPLETED);
        long cancelledOrders = countByStatus(dateFilteredBookings, BookingStatus.CANCELLED);

        double totalEarnings = sumEarnings(dateFilteredBookings, servicesById);

        LocalDate today = LocalDate.now();
        double todayEarnings = sumEarnings(
                allBookings.stream()
                        .filter(booking -> booking.getDate() != null && booking.getDate().isEqual(today))
                        .filter(booking -> resolveStatus(booking) == BookingStatus.COMPLETED)
                        .toList(),
                servicesById);

        double thisMonthEarnings = sumEarnings(
                allBookings.stream()
                        .filter(booking -> booking.getDate() != null
                                && booking.getDate().getYear() == today.getYear()
                                && booking.getDate().getMonth() == today.getMonth())
                        .filter(booking -> resolveStatus(booking) == BookingStatus.COMPLETED)
                        .toList(),
                servicesById);

        double averageCompletedOrderValue = completedOrders == 0 ? 0.0 : totalEarnings / completedOrders;

        List<ProviderEarningsOrderItemResponse> recentCompletedOrders = dateFilteredBookings.stream()
                .filter(booking -> resolveStatus(booking) == BookingStatus.COMPLETED)
                .limit(5)
                .map(booking -> {
                    ServiceEntity service = servicesById.get(booking.getServiceId());
                    return new ProviderEarningsOrderItemResponse(
                            booking.getId(),
                            service == null ? null : service.getName(),
                            service == null ? 0.0 : defaultDouble(service.getPrice()),
                            booking.getDate() == null ? null : booking.getDate().toString(),
                            resolveStatus(booking).name());
                })
                .toList();

        return new ProviderEarningsResponse(
                providerId,
                totalEarnings,
                todayEarnings,
                thisMonthEarnings,
                pendingOrders,
                inProgressOrders,
                completedOrders,
                cancelledOrders,
                averageCompletedOrderValue,
                recentCompletedOrders);
    }

    private long countByStatus(List<Booking> bookings, BookingStatus status) {
        return bookings.stream().filter(booking -> resolveStatus(booking) == status).count();
    }

    private double sumEarnings(List<Booking> bookings, Map<Long, ServiceEntity> servicesById) {
        return bookings.stream()
                .filter(booking -> resolveStatus(booking) == BookingStatus.COMPLETED)
                .map(booking -> servicesById.get(booking.getServiceId()))
                .filter(service -> service != null)
                .mapToDouble(service -> defaultDouble(service.getPrice()))
                .sum();
    }

    private boolean isWithinRange(LocalDate date, LocalDate fromDate, LocalDate toDate) {
        if (date == null) {
            return false;
        }

        if (fromDate != null && date.isBefore(fromDate)) {
            return false;
        }

        if (toDate != null && date.isAfter(toDate)) {
            return false;
        }

        return true;
    }

    private BookingStatus resolveStatus(Booking booking) {
        return booking.getStatus() == null ? BookingStatus.PENDING : booking.getStatus();
    }

    private double defaultDouble(Double value) {
        return value == null ? 0.0 : value;
    }
}
