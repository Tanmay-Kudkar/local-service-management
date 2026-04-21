package com.lsm.backend.dto;

import lombok.Data;

@Data
public class UserProfileUpdateRequest {
    private String name;
    private String contactNumber;
    private String address;
    private String city;
    private String state;
    private String pincode;
}