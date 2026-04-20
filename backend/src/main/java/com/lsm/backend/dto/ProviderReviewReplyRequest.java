package com.lsm.backend.dto;

import lombok.Data;

@Data
public class ProviderReviewReplyRequest {
    private Long providerId;
    private String response;
}
