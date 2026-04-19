package com.lsm.backend.controller;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.lsm.backend.entity.ServiceEntity;
import com.lsm.backend.service.ServiceCatalogService;

@RestController
@RequestMapping("/services")
public class ServiceController {

    private final ServiceCatalogService serviceCatalogService;

    public ServiceController(ServiceCatalogService serviceCatalogService) {
        this.serviceCatalogService = serviceCatalogService;
    }

    @GetMapping
    public List<ServiceEntity> getServices() {
        return serviceCatalogService.getAllServices();
    }
}