package com.lsm.backend.dto;

import java.time.LocalDate;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class BookingTrackingResponse {
    private Long id;
    private Long userId;
    private Long serviceId;
    private String serviceName;
    private Double servicePrice;
    private Long providerId;
    private String providerName;
    private LocalDate date;
    private String status;
    private String trackingNote;
    private Boolean liveLocationSharingEnabled;
    private Double providerLatitude;
    private Double providerLongitude;
    private String providerLocationUpdatedAt;
    private String createdAt;
    private String updatedAt;
    private Boolean reviewSubmitted;
}
