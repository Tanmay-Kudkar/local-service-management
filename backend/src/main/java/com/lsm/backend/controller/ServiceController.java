package com.lsm.backend.controller;

import java.util.List;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.lsm.backend.dto.ServiceCreateRequest;
import com.lsm.backend.dto.ServiceUpdateRequest;
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

    @GetMapping("/types")
    public ResponseEntity<List<String>> getServiceTypes() {
        return ResponseEntity.ok(serviceCatalogService.getAllServiceTypes());
    }

    @GetMapping("/provider/{providerId}")
    public ResponseEntity<List<ServiceEntity>> getProviderServices(@PathVariable Long providerId) {
        return ResponseEntity.ok(serviceCatalogService.getServicesByProviderId(providerId));
    }

    @PostMapping("/provider")
    public ResponseEntity<ServiceEntity> createServiceByProvider(@RequestBody ServiceCreateRequest request) {
        return ResponseEntity.ok(serviceCatalogService.createServiceByProvider(request));
    }

    @PutMapping("/provider/{serviceId}")
    public ResponseEntity<ServiceEntity> updateServiceByProvider(
            @PathVariable Long serviceId,
            @RequestBody ServiceUpdateRequest request) {
        return ResponseEntity.ok(serviceCatalogService.updateServiceByProvider(serviceId, request));
    }

    @DeleteMapping("/provider/{serviceId}")
    public ResponseEntity<Map<String, String>> deleteServiceByProvider(
            @PathVariable Long serviceId,
            @RequestParam Long providerId) {
        serviceCatalogService.deleteServiceByProvider(serviceId, providerId);
        return ResponseEntity.ok(Map.of("message", "Service deleted successfully"));
    }
}