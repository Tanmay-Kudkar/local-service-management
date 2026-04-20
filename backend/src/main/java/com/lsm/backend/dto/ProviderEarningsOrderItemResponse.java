package com.lsm.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class ProviderEarningsOrderItemResponse {
    private Long bookingId;
    private String serviceName;
    private Double amount;
    private String date;
    private String status;
}
