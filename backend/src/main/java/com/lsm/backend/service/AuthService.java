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

        if (userRepository.existsByEmail(request.getEmail())) {
            throw new BadRequestException("Email already registered");
        }

        User user = new User();
        user.setName(request.getName());
        user.setEmail(request.getEmail());
        user.setPassword(request.getPassword());
        user.setRole(request.getRole() == null ? Role.USER : request.getRole());

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
}