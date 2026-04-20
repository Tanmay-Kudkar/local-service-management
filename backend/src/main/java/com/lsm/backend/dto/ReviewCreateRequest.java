package com.lsm.backend.dto;

import lombok.Data;

@Data
public class ReviewCreateRequest {
    private Long bookingId;
    private Long userId;
    private Integer rating;
    private String comment;
}
