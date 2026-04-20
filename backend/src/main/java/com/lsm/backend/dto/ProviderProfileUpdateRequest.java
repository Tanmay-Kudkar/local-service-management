package com.lsm.backend.dto;

import lombok.Data;

@Data
public class ProviderProfileUpdateRequest {
    private String contactNumber;
    private String address;
    private String city;
    private String state;
    private String pincode;
    private Integer experienceYears;
    private String skills;
    private String bio;
}
