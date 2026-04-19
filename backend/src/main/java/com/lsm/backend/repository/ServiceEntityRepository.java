package com.lsm.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.lsm.backend.entity.ServiceEntity;

public interface ServiceEntityRepository extends JpaRepository<ServiceEntity, Long> {
}