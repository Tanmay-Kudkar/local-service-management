package com.lsm.backend.dto;

import java.time.LocalDate;

import lombok.Data;

@Data
public class BookingRequest {
    private Long userId;
    private Long serviceId;
    private LocalDate date;
}