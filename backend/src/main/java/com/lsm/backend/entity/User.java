package com.lsm.backend.entity;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Lob;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "users")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(nullable = false)
    private String password;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Role role;

    @Column(length = 20)
    private String contactNumber;

    @Column(length = 255)
    private String address;

    @Column(length = 100)
    private String city;

    @Column(length = 100)
    private String state;

    @Column(length = 20)
    private String pincode;

    @Column(length = 600)
    private String profileImageUrl;

    @Lob
    @Column(name = "profile_image_data")
    private byte[] profileImageData;

    @Column(length = 100)
    private String profileImageContentType;

    private Integer experienceYears;

    @Column(length = 500)
    private String skills;

    @Column(length = 1000)
    private String bio;

    @Column
    private Boolean verified = false;

    @Column
    private Double ratingAverage = 0.0;

    @Column
    private Integer totalReviews = 0;

    @Column
    private Boolean liveLocationSharingEnabled = false;

    @Column
    private Double liveLatitude;

    @Column
    private Double liveLongitude;

    @Column
    private LocalDateTime liveLocationUpdatedAt;
}