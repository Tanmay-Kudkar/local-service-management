package com.lsm.backend.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.lsm.backend.entity.Booking;

public interface BookingRepository extends JpaRepository<Booking, Long> {
    List<Booking> findByUserId(Long userId);
}