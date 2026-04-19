package com.lsm.backend.service;

import java.util.List;

import org.springframework.stereotype.Service;

import com.lsm.backend.entity.ServiceEntity;
import com.lsm.backend.repository.ServiceEntityRepository;

@Service
public class ServiceCatalogService {

    private final ServiceEntityRepository serviceEntityRepository;

    public ServiceCatalogService(ServiceEntityRepository serviceEntityRepository) {
        this.serviceEntityRepository = serviceEntityRepository;
    }

    public List<ServiceEntity> getAllServices() {
        return serviceEntityRepository.findAll();
    }
}