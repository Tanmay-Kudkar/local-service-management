package com.lsm.backend.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import com.lsm.backend.entity.Role;
import com.lsm.backend.entity.User;

public interface UserRepository extends JpaRepository<User, Long> {
    boolean existsByEmail(String email);

    boolean existsByEmailIgnoreCase(String email);

    Optional<User> findByEmail(String email);

    Optional<User> findByEmailIgnoreCase(String email);

    @Query("select u.id as id, u.name as name, u.password as password, u.role as role " +
            "from User u where lower(u.email) = lower(:email)")
    Optional<AuthLoginProjection> findAuthLoginByEmail(@Param("email") String email);

    @Modifying
    @Transactional
    @Query("update User u set u.role = :role where u.id = :userId")
    int updateRoleById(@Param("userId") Long userId, @Param("role") Role role);

    interface AuthLoginProjection {
        Long getId();

        String getName();

        String getPassword();

        Role getRole();
    }
}