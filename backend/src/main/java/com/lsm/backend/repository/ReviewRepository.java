package com.lsm.backend.repository;

import java.util.Collection;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.lsm.backend.entity.Review;

public interface ReviewRepository extends JpaRepository<Review, Long> {
    boolean existsByBookingId(Long bookingId);

    List<Review> findByBookingIdIn(Collection<Long> bookingIds);

    List<Review> findByProviderIdOrderByCreatedAtDesc(Long providerId);
}
