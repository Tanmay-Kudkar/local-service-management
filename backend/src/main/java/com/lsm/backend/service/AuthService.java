package com.lsm.backend.service;

import java.util.Locale;
import java.util.regex.Pattern;

import org.springframework.stereotype.Service;

import com.lsm.backend.dto.AuthResponse;
import com.lsm.backend.dto.LoginRequest;
import com.lsm.backend.dto.RegisterRequest;
import com.lsm.backend.entity.Role;
import com.lsm.backend.entity.User;
import com.lsm.backend.exception.BadRequestException;
import com.lsm.backend.repository.UserRepository;

@Service
public class AuthService {

    private static final Pattern INDIAN_MOBILE_PATTERN = Pattern.compile("^[6-9]\\d{9}$");
    private static final Pattern INDIAN_PINCODE_PATTERN = Pattern.compile("^[1-9]\\d{5}$");

    private final UserRepository userRepository;

    public AuthService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public AuthResponse register(RegisterRequest request) {
        if (request.getName() == null || request.getEmail() == null || request.getPassword() == null) {
            throw new BadRequestException("Name, email and password are required");
        }

        String name = request.getName().trim();
        String email = normalizeEmail(request.getEmail());
        String password = request.getPassword().trim();

        if (name.isEmpty() || email.isEmpty() || password.isEmpty()) {
            throw new BadRequestException("Name, email and password cannot be empty");
        }

        if (userRepository.existsByEmailIgnoreCase(email)) {
            throw new BadRequestException("Email already registered");
        }

        Role role = request.getRole() == null ? Role.USER : request.getRole();

        if (role == Role.PROVIDER) {
            validateProviderRegistrationData(request);
        }

        User user = new User();
        user.setName(name);
        user.setEmail(email);
        user.setPassword(password);
        user.setRole(role);
        applyProviderProfileFields(user, request);
        user.setVerified(false);
        user.setRatingAverage(0.0);
        user.setTotalReviews(0);

        User savedUser = userRepository.save(user);
        return new AuthResponse(
                savedUser.getId(),
                savedUser.getName(),
                normalizeRole(savedUser).name(),
                "Registration successful");
    }

    public AuthResponse login(LoginRequest request) {
        if (request.getEmail() == null || request.getPassword() == null) {
            throw new BadRequestException("Email and password are required");
        }

        String email = normalizeEmail(request.getEmail());
        String password = request.getPassword().trim();

        if (email.isEmpty() || password.isEmpty()) {
            throw new BadRequestException("Email and password are required");
        }

        UserRepository.AuthLoginProjection authUser = userRepository.findAuthLoginByEmail(email)
                .orElseThrow(() -> new BadRequestException("Invalid email or password"));

        String storedPassword = normalizeNullableText(authUser.getPassword());
        if (storedPassword == null) {
            throw new BadRequestException("Account password is not set. Please register again.");
        }

        if (!storedPassword.equals(password)) {
            throw new BadRequestException("Invalid email or password");
        }

        Role role = normalizeRoleForLogin(authUser);
        String userName = normalizeNullableText(authUser.getName());
        if (userName == null) {
            userName = "User";
        }

        return new AuthResponse(
                authUser.getId(),
                userName,
                role.name(),
                "Login successful");
    }

    private Role normalizeRoleForLogin(UserRepository.AuthLoginProjection authUser) {
        if (authUser.getRole() == null) {
            userRepository.updateRoleById(authUser.getId(), Role.USER);
            return Role.USER;
        }

        return authUser.getRole();
    }

    private Role normalizeRole(User user) {
        if (user.getRole() == null) {
            user.setRole(Role.USER);
            userRepository.save(user);
        }
        return user.getRole();
    }

    private void validateProviderRegistrationData(RegisterRequest request) {
        String contactNumber = normalizeNullableText(request.getContactNumber());
        String address = normalizeNullableText(request.getAddress());
        String city = normalizeNullableText(request.getCity());
        String pincode = normalizeNullableText(request.getPincode());

        if (contactNumber == null || address == null || city == null) {
            throw new BadRequestException("Provider registration requires contact number, address and city");
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
    }

    private void applyProviderProfileFields(User user, RegisterRequest request) {
        user.setContactNumber(normalizeNullableText(request.getContactNumber()));
        user.setAddress(normalizeNullableText(request.getAddress()));
        user.setCity(normalizeNullableText(request.getCity()));
        user.setState(normalizeNullableText(request.getState()));
        user.setPincode(normalizeNullableText(request.getPincode()));
        user.setExperienceYears(request.getExperienceYears());
        user.setSkills(normalizeNullableText(request.getSkills()));
        user.setBio(normalizeNullableText(request.getBio()));
    }

    private String normalizeNullableText(String value) {
        if (value == null) {
            return null;
        }

        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private String normalizeEmail(String value) {
        return value.trim().toLowerCase(Locale.ROOT);
    }
}