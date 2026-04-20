package com.lsm.backend.service;

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

    private final UserRepository userRepository;

    public AuthService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public AuthResponse register(RegisterRequest request) {
        if (request.getName() == null || request.getEmail() == null || request.getPassword() == null) {
            throw new BadRequestException("Name, email and password are required");
        }

        String name = request.getName().trim();
        String email = request.getEmail().trim();
        String password = request.getPassword().trim();

        if (name.isEmpty() || email.isEmpty() || password.isEmpty()) {
            throw new BadRequestException("Name, email and password cannot be empty");
        }

        if (userRepository.existsByEmail(email)) {
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

        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new BadRequestException("Invalid email or password"));

        if (!user.getPassword().equals(request.getPassword())) {
            throw new BadRequestException("Invalid email or password");
        }

        Role role = normalizeRole(user);

        return new AuthResponse(
            user.getId(),
            user.getName(),
            role.name(),
            "Login successful");
    }

    private Role normalizeRole(User user) {
        if (user.getRole() == null) {
            user.setRole(Role.USER);
            userRepository.save(user);
        }
        return user.getRole();
    }

    private void validateProviderRegistrationData(RegisterRequest request) {
        if (isBlank(request.getContactNumber())
                || isBlank(request.getAddress())
                || isBlank(request.getCity())) {
            throw new BadRequestException("Provider registration requires contact number, address and city");
        }

        if (request.getExperienceYears() != null && request.getExperienceYears() < 0) {
            throw new BadRequestException("experienceYears cannot be negative");
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

    private boolean isBlank(String value) {
        return value == null || value.trim().isEmpty();
    }
}