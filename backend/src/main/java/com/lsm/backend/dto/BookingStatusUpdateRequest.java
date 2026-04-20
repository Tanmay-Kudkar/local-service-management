package com.lsm.backend.dto;

import lombok.Data;

@Data
public class BookingStatusUpdateRequest {
    private Long providerId;
    private String status;
    private String trackingNote;
}
