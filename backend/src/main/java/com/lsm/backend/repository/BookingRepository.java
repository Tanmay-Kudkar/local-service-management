package com.lsm.backend.repository;

import java.time.LocalDate;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.lsm.backend.entity.Booking;
import com.lsm.backend.entity.BookingStatus;

public interface BookingRepository extends JpaRepository<Booking, Long> {
    List<Booking> findByUserIdOrderByCreatedAtDesc(Long userId);

    List<Booking> findByProviderIdOrderByCreatedAtDesc(Long providerId);

    List<Booking> findByProviderIdAndStatusOrderByUpdatedAtDesc(Long providerId, BookingStatus status);

    boolean existsByServiceIdAndDateAndStatusIn(Long serviceId, LocalDate date, List<BookingStatus> statuses);

    long countByProviderIdAndStatus(Long providerId, BookingStatus status);

    List<Booking> findByProviderIdAndDateBetweenAndStatusOrderByDateDesc(
            Long providerId,
            LocalDate startDate,
            LocalDate endDate,
            BookingStatus status);
}