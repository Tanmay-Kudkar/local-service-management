package com.lsm.backend.service;

import org.springframework.stereotype.Service;

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

        Role role = user.getRole();
        if (role == null) {
            user.setRole(Role.USER);
            userRepository.save(user);
            role = Role.USER;
        }

        return new UserProfileResponse(
                user.getId(),
                user.getName(),
                user.getEmail(),
            role.name());
    }
}