package com.lsm.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class ReviewResponse {
    private Long id;
    private Long bookingId;
    private Long userId;
    private String userName;
    private Long providerId;
    private Long serviceId;
    private String serviceName;
    private Integer rating;
    private String comment;
    private String providerResponse;
    private String createdAt;
}
