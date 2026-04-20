package com.lsm.backend.dto;

import lombok.Data;

@Data
public class ServiceUpdateRequest {
    private Long providerId;
    private String name;
    private Double price;
    private String description;
}
