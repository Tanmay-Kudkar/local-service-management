package com.lsm.backend.service;

import java.time.LocalDateTime;
import java.util.Base64;

import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import com.lsm.backend.dto.ProviderProfileUpdateRequest;
import com.lsm.backend.dto.ProviderLocationUpdateRequest;
import com.lsm.backend.dto.UserProfileResponse;
import com.lsm.backend.entity.Role;
import com.lsm.backend.entity.User;
import com.lsm.backend.exception.BadRequestException;
import com.lsm.backend.repository.UserRepository;

@Service
public class UserProfileService {

    private final UserRepository userRepository;

    public UserProfileService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public UserProfileResponse getProfile(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BadRequestException("User not found"));

        Role role = normalizeRole(user);
        return toResponse(user, role);
    }

    public UserProfileResponse updateProviderProfile(Long userId, ProviderProfileUpdateRequest request) {
        if (request == null) {
            throw new BadRequestException("Profile request body is required");
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BadRequestException("User not found"));

        Role role = normalizeRole(user);
        if (role != Role.PROVIDER) {
            throw new BadRequestException("Only PROVIDER accounts can update provider profile");
        }

        if (isBlank(request.getContactNumber()) || isBlank(request.getAddress()) || isBlank(request.getCity())) {
            throw new BadRequestException("contactNumber, address and city are required");
        }

        if (request.getExperienceYears() != null && request.getExperienceYears() < 0) {
            throw new BadRequestException("experienceYears cannot be negative");
        }

        user.setContactNumber(normalizeNullableText(request.getContactNumber()));
        user.setAddress(normalizeNullableText(request.getAddress()));
        user.setCity(normalizeNullableText(request.getCity()));
        user.setState(normalizeNullableText(request.getState()));
        user.setPincode(normalizeNullableText(request.getPincode()));
        user.setExperienceYears(request.getExperienceYears());
        user.setSkills(normalizeNullableText(request.getSkills()));
        user.setBio(normalizeNullableText(request.getBio()));

        User savedUser = userRepository.save(user);
        return toResponse(savedUser, role);
    }

    public UserProfileResponse updateProviderLiveLocation(Long userId, ProviderLocationUpdateRequest request) {
        if (request == null) {
            throw new BadRequestException("Location request body is required");
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BadRequestException("User not found"));

        Role role = normalizeRole(user);
        if (role != Role.PROVIDER) {
            throw new BadRequestException("Only PROVIDER accounts can update live location");
        }

        if (request.getLiveLocationSharingEnabled() != null) {
            user.setLiveLocationSharingEnabled(request.getLiveLocationSharingEnabled());
        }

        Double latitude = request.getLatitude();
        Double longitude = request.getLongitude();
        if (latitude != null || longitude != null) {
            if (latitude == null || longitude == null) {
                throw new BadRequestException("latitude and longitude must be provided together");
            }

            if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
                throw new BadRequestException("Invalid latitude/longitude values");
            }

            user.setLiveLatitude(latitude);
            user.setLiveLongitude(longitude);
            user.setLiveLocationUpdatedAt(LocalDateTime.now());
        }

        User savedUser = userRepository.save(user);
        return toResponse(savedUser, role);
    }

    public UserProfileResponse uploadProfileImage(Long userId, MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BadRequestException("Image file is required");
        }

        String contentType = normalizeNullableText(file.getContentType());
        if (contentType == null || !contentType.startsWith("image/")) {
            throw new BadRequestException("Only image files are allowed");
        }

        if (file.getSize() > 3L * 1024 * 1024) {
            throw new BadRequestException("Image size must be <= 3 MB");
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BadRequestException("User not found"));

        byte[] imageData;
        try {
            imageData = file.getBytes();
        } catch (Exception ex) {
            throw new BadRequestException("Unable to read uploaded image");
        }

        user.setProfileImageData(imageData);
        user.setProfileImageContentType(contentType);
        user.setProfileImageUrl(null);

        User savedUser = userRepository.save(user);
        return toResponse(savedUser, normalizeRole(savedUser));
    }

    public UserProfileResponse removeProfileImage(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BadRequestException("User not found"));

        user.setProfileImageData(null);
        user.setProfileImageContentType(null);
        user.setProfileImageUrl(null);

        User savedUser = userRepository.save(user);
        return toResponse(savedUser, normalizeRole(savedUser));
    }

    private UserProfileResponse toResponse(User user, Role role) {
        boolean verified = user.getVerified() != null && user.getVerified();
        double ratingAverage = user.getRatingAverage() == null ? 0.0 : user.getRatingAverage();
        int totalReviews = user.getTotalReviews() == null ? 0 : user.getTotalReviews();
        String profileImageBase64 = user.getProfileImageData() == null
                ? null
                : Base64.getEncoder().encodeToString(user.getProfileImageData());

        String liveLocationUpdatedAt = user.getLiveLocationUpdatedAt() == null
                ? null
                : user.getLiveLocationUpdatedAt().toString();

        return new UserProfileResponse(
                user.getId(),
                user.getName(),
                user.getEmail(),
                role.name(),
                user.getContactNumber(),
                user.getAddress(),
                user.getCity(),
                user.getState(),
                user.getPincode(),
                user.getProfileImageUrl(),
                profileImageBase64,
                user.getProfileImageContentType(),
                user.getExperienceYears(),
                user.getSkills(),
                user.getBio(),
                verified,
                ratingAverage,
                totalReviews,
                defaultBoolean(user.getLiveLocationSharingEnabled()),
                user.getLiveLatitude(),
                user.getLiveLongitude(),
                liveLocationUpdatedAt);
    }

    private Role normalizeRole(User user) {
        Role role = user.getRole();
        if (role == null) {
            user.setRole(Role.USER);
            userRepository.save(user);
            role = Role.USER;
        }
        return role;
    }

    private String normalizeNullableText(String value) {
        if (value == null) {
            return null;
        }

        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private boolean isBlank(String value) {
        return value == null || value.trim().isEmpty();
    }

    private boolean defaultBoolean(Boolean value) {
        return value != null && value;
    }
}