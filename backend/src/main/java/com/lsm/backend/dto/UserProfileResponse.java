package com.lsm.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class UserProfileResponse {
    private Long userId;
    private String name;
    private String email;
    private String role;
    private String contactNumber;
    private String address;
    private String city;
    private String state;
    private String pincode;
    private String profileImageUrl;
    private String profileImageBase64;
    private String profileImageContentType;
    private Integer experienceYears;
    private String skills;
    private String bio;
    private Boolean verified;
    private Double ratingAverage;
    private Integer totalReviews;
    private Boolean liveLocationSharingEnabled;
    private Double liveLatitude;
    private Double liveLongitude;
    private String liveLocationUpdatedAt;
}