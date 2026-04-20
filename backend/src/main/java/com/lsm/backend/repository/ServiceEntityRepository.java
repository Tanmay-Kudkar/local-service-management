package com.lsm.backend.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import com.lsm.backend.entity.ServiceEntity;

public interface ServiceEntityRepository extends JpaRepository<ServiceEntity, Long> {
    boolean existsByName(String name);

    boolean existsByProviderIdIsNullAndNameIgnoreCase(String name);

    boolean existsByProviderIdAndNameIgnoreCase(Long providerId, String name);

    boolean existsByProviderIdAndNameIgnoreCaseAndIdNot(Long providerId, String name, Long id);

    List<ServiceEntity> findByProviderId(Long providerId);

    @Query("select distinct s.name from ServiceEntity s order by s.name asc")
    List<String> findDistinctServiceNames();
}