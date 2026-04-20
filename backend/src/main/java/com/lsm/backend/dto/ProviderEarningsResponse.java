package com.lsm.backend.dto;

import java.util.List;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class ProviderEarningsResponse {
    private Long providerId;
    private Double totalEarnings;
    private Double todayEarnings;
    private Double thisMonthEarnings;
    private Long pendingOrders;
    private Long inProgressOrders;
    private Long completedOrders;
    private Long cancelledOrders;
    private Double averageCompletedOrderValue;
    private List<ProviderEarningsOrderItemResponse> recentCompletedOrders;
}
