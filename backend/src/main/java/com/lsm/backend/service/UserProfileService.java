package com.lsm.backend.service;

import java.time.LocalDateTime;
import java.util.Base64;
import java.util.Locale;
import java.util.regex.Pattern;

import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import com.lsm.backend.dto.ProviderProfileUpdateRequest;
import com.lsm.backend.dto.ProviderLocationUpdateRequest;
import com.lsm.backend.dto.UserProfileUpdateRequest;
import com.lsm.backend.dto.UserProfileResponse;
import com.lsm.backend.entity.Role;
import com.lsm.backend.entity.User;
import com.lsm.backend.exception.BadRequestException;
import com.lsm.backend.repository.UserRepository;

@Service
public class UserProfileService {

    private static final Pattern INDIAN_MOBILE_PATTERN = Pattern.compile("^[6-9]\\d{9}$");
    private static final Pattern INDIAN_PINCODE_PATTERN = Pattern.compile("^[1-9]\\d{5}$");

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

    public UserProfileResponse updateUserProfile(Long userId, UserProfileUpdateRequest request) {
        if (request == null) {
            throw new BadRequestException("Profile request body is required");
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BadRequestException("User not found"));

        Role role = normalizeRole(user);

        String name = normalizeNullableText(request.getName());
        if (name == null) {
            throw new BadRequestException("name is required");
        }

        if (name.length() < 2 || name.length() > 120) {
            throw new BadRequestException("name must be between 2 and 120 characters");
        }

        String contactNumber = normalizeNullableText(request.getContactNumber());
        String address = normalizeNullableText(request.getAddress());
        String pincode = normalizeNullableText(request.getPincode());

        if (contactNumber != null && !INDIAN_MOBILE_PATTERN.matcher(contactNumber).matches()) {
            throw new BadRequestException("contactNumber must be a valid 10-digit Indian mobile number");
        }

        if (address != null && address.length() < 10) {
            throw new BadRequestException("address must be at least 10 characters");
        }

        if (pincode != null && !INDIAN_PINCODE_PATTERN.matcher(pincode).matches()) {
            throw new BadRequestException("pincode must be a valid 6-digit Indian pincode");
        }

        user.setName(name);
        user.setContactNumber(contactNumber);
        user.setAddress(address);
        user.setCity(normalizeNullableText(request.getCity()));
        user.setState(normalizeNullableText(request.getState()));
        user.setPincode(pincode);

        User savedUser = userRepository.save(user);
        return toResponse(savedUser, role);
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

        String contactNumber = normalizeNullableText(request.getContactNumber());
        String address = normalizeNullableText(request.getAddress());
        String city = normalizeNullableText(request.getCity());
        String pincode = normalizeNullableText(request.getPincode());

        if (contactNumber == null || address == null || city == null) {
            throw new BadRequestException("contactNumber, address and city are required");
        }

        if (!INDIAN_MOBILE_PATTERN.matcher(contactNumber).matches()) {
            throw new BadRequestException("contactNumber must be a valid 10-digit Indian mobile number");
        }

        if (address.length() < 10) {
            throw new BadRequestException("address must be at least 10 characters");
        }

        if (pincode != null && !INDIAN_PINCODE_PATTERN.matcher(pincode).matches()) {
            throw new BadRequestException("pincode must be a valid 6-digit Indian pincode");
        }

        Integer experienceYears = request.getExperienceYears();
        if (experienceYears != null && (experienceYears < 0 || experienceYears > 60)) {
            throw new BadRequestException("experienceYears must be between 0 and 60");
        }

        user.setContactNumber(contactNumber);
        user.setAddress(address);
        user.setCity(city);
        user.setState(normalizeNullableText(request.getState()));
        user.setPincode(pincode);
        user.setExperienceYears(experienceYears);
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

        if (file.getSize() > 3L * 1024 * 1024) {
            throw new BadRequestException("Image size must be <= 3 MB");
        }

        byte[] imageData;
        try {
            imageData = file.getBytes();
        } catch (Exception ex) {
            throw new BadRequestException("Unable to read uploaded image");
        }

        String contentType = resolveImageContentType(
                file.getContentType(),
                file.getOriginalFilename(),
                imageData);
        if (contentType == null) {
            throw new BadRequestException("Only images are allowed (jpg, jpeg, png, gif, webp, bmp)");
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BadRequestException("User not found"));

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

    private String resolveImageContentType(
            String declaredContentType,
            String originalFilename,
            byte[] imageData) {
        String detectedContentType = detectImageContentType(imageData);
        if (detectedContentType != null) {
            return detectedContentType;
        }

        String normalizedDeclared = normalizeNullableText(declaredContentType);
        if (normalizedDeclared != null) {
            String lowered = normalizedDeclared.toLowerCase(Locale.ROOT);
            if (lowered.startsWith("image/")) {
                return lowered;
            }
        }

        return inferImageContentTypeFromExtension(originalFilename);
    }

    private String inferImageContentTypeFromExtension(String originalFilename) {
        String fileName = normalizeNullableText(originalFilename);
        if (fileName == null) {
            return null;
        }

        int dotIndex = fileName.lastIndexOf('.');
        if (dotIndex < 0 || dotIndex == fileName.length() - 1) {
            return null;
        }

        String extension = fileName.substring(dotIndex + 1).toLowerCase(Locale.ROOT);
        return switch (extension) {
            case "jpg", "jpeg" -> "image/jpeg";
            case "png" -> "image/png";
            case "gif" -> "image/gif";
            case "webp" -> "image/webp";
            case "bmp" -> "image/bmp";
            default -> null;
        };
    }

    private String detectImageContentType(byte[] imageData) {
        if (imageData == null || imageData.length < 4) {
            return null;
        }

        if (hasPrefix(imageData, 0xFF, 0xD8, 0xFF)) {
            return "image/jpeg";
        }

        if (hasPrefix(imageData, 0x89, 0x50, 0x4E, 0x47)) {
            return "image/png";
        }

        if (hasPrefix(imageData, 0x47, 0x49, 0x46, 0x38)) {
            return "image/gif";
        }

        if (hasPrefix(imageData, 0x42, 0x4D)) {
            return "image/bmp";
        }

        if (isWebp(imageData)) {
            return "image/webp";
        }

        return null;
    }

    private boolean hasPrefix(byte[] imageData, int... prefix) {
        if (imageData.length < prefix.length) {
            return false;
        }

        for (int index = 0; index < prefix.length; index++) {
            if ((imageData[index] & 0xFF) != prefix[index]) {
                return false;
            }
        }

        return true;
    }

    private boolean isWebp(byte[] imageData) {
        if (imageData.length < 12) {
            return false;
        }

        return hasAsciiAt(imageData, 0, "RIFF") && hasAsciiAt(imageData, 8, "WEBP");
    }

    private boolean hasAsciiAt(byte[] imageData, int offset, String expected) {
        if (offset < 0 || imageData.length < offset + expected.length()) {
            return false;
        }

        for (int index = 0; index < expected.length(); index++) {
            if ((imageData[offset + index] & 0xFF) != expected.charAt(index)) {
                return false;
            }
        }

        return true;
    }

    private boolean isBlank(String value) {
        return value == null || value.trim().isEmpty();
    }

    private boolean defaultBoolean(Boolean value) {
        return value != null && value;
    }
}