package com.lsm.backend.dto;

import lombok.Data;

@Data
public class ServiceCreateRequest {
    private Long providerId;
    private String name;
    private Double price;
    private String description;
}