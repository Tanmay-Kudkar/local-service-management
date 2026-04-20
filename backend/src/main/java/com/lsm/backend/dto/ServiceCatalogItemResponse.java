package com.lsm.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class ServiceCatalogItemResponse {
    private Long id;
    private String name;
    private Double price;
    private String description;
    private Long providerId;
    private String providerName;
    private String providerContactNumber;
    private String providerAddress;
    private String providerCity;
    private String providerState;
    private String providerPincode;
    private String providerProfileImageUrl;
    private String providerProfileImageBase64;
    private String providerProfileImageContentType;
    private Integer providerExperienceYears;
    private String providerSkills;
    private String providerBio;
    private Boolean providerVerified;
    private Double providerRatingAverage;
    private Integer providerTotalReviews;
    private Boolean providerLiveLocationSharingEnabled;
    private Double providerLiveLatitude;
    private Double providerLiveLongitude;
    private String providerLiveLocationUpdatedAt;
    private Double providerDistanceKm;
    private Boolean available;
}
