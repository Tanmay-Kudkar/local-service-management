package com.lsm.backend.dto;

import lombok.Data;

@Data
public class ProviderLocationUpdateRequest {
    private Boolean liveLocationSharingEnabled;
    private Double latitude;
    private Double longitude;
}
