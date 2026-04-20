package com.lsm.backend.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.lsm.backend.dto.ProviderLocationUpdateRequest;
import com.lsm.backend.dto.ProviderProfileUpdateRequest;
import com.lsm.backend.dto.UserProfileResponse;
import com.lsm.backend.service.UserProfileService;

@RestController
@RequestMapping("/users")
public class UserController {

    private final UserProfileService userProfileService;

    public UserController(UserProfileService userProfileService) {
        this.userProfileService = userProfileService;
    }

    @GetMapping("/{userId}")
    public ResponseEntity<UserProfileResponse> getUserProfile(@PathVariable Long userId) {
        return ResponseEntity.ok(userProfileService.getProfile(userId));
    }

    @PutMapping("/{userId}/provider-profile")
    public ResponseEntity<UserProfileResponse> updateProviderProfile(
            @PathVariable Long userId,
            @RequestBody ProviderProfileUpdateRequest request) {
        return ResponseEntity.ok(userProfileService.updateProviderProfile(userId, request));
    }

    @PutMapping("/{userId}/provider-location")
    public ResponseEntity<UserProfileResponse> updateProviderLocation(
            @PathVariable Long userId,
            @RequestBody ProviderLocationUpdateRequest request) {
        return ResponseEntity.ok(userProfileService.updateProviderLiveLocation(userId, request));
    }

    @PostMapping(value = "/{userId}/profile-image", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<UserProfileResponse> uploadProfileImage(
            @PathVariable Long userId,
            @RequestPart("file") MultipartFile file) {
        return ResponseEntity.ok(userProfileService.uploadProfileImage(userId, file));
    }

    @DeleteMapping("/{userId}/profile-image")
    public ResponseEntity<UserProfileResponse> removeProfileImage(@PathVariable Long userId) {
        return ResponseEntity.ok(userProfileService.removeProfileImage(userId));
    }
}