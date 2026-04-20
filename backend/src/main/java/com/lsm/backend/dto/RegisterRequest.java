package com.lsm.backend.dto;

import com.lsm.backend.entity.Role;

import lombok.Data;

@Data
public class RegisterRequest {
    private String name;
    private String email;
    private String password;
    private Role role;
    private String contactNumber;
    private String address;
    private String city;
    private String state;
    private String pincode;
    private Integer experienceYears;
    private String skills;
    private String bio;
}