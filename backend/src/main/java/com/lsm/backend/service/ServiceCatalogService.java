package com.lsm.backend.service;

import java.util.List;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;

import com.lsm.backend.dto.ServiceCreateRequest;
import com.lsm.backend.dto.ServiceUpdateRequest;
import com.lsm.backend.entity.Role;
import com.lsm.backend.entity.ServiceEntity;
import com.lsm.backend.entity.User;
import com.lsm.backend.exception.BadRequestException;
import com.lsm.backend.repository.ServiceEntityRepository;
import com.lsm.backend.repository.UserRepository;

@Service
public class ServiceCatalogService {

    private final ServiceEntityRepository serviceEntityRepository;
    private final UserRepository userRepository;

    public ServiceCatalogService(
            ServiceEntityRepository serviceEntityRepository,
            UserRepository userRepository) {
        this.serviceEntityRepository = serviceEntityRepository;
        this.userRepository = userRepository;
    }

    public List<ServiceEntity> getAllServices() {
        return serviceEntityRepository.findAll();
    }

    public List<ServiceEntity> getServicesByProviderId(Long providerId) {
        return serviceEntityRepository.findByProviderId(providerId);
    }

    public List<String> getAllServiceTypes() {
        return serviceEntityRepository.findDistinctServiceNames();
    }

    public ServiceEntity createServiceByProvider(ServiceCreateRequest request) {
        validateServicePayload(
                request.getProviderId(),
                request.getName(),
                request.getPrice(),
                request.getDescription());

        String name = request.getName().trim();
        String description = request.getDescription().trim();

        User provider = getValidatedProvider(request.getProviderId());

        if (serviceEntityRepository.existsByProviderIdAndNameIgnoreCase(provider.getId(), name)) {
            throw new BadRequestException("You already published this service type.");
        }

        ServiceEntity service = new ServiceEntity();
        service.setName(name);
        service.setPrice(request.getPrice());
        service.setDescription(description);
        service.setProviderId(provider.getId());

        return serviceEntityRepository.save(service);
    }

    public ServiceEntity updateServiceByProvider(Long serviceId, ServiceUpdateRequest request) {
        validateServicePayload(
                request.getProviderId(),
                request.getName(),
                request.getPrice(),
                request.getDescription());

        String name = request.getName().trim();
        String description = request.getDescription().trim();

        User provider = getValidatedProvider(request.getProviderId());

        ServiceEntity service = serviceEntityRepository.findById(serviceId)
                .orElseThrow(() -> new BadRequestException("Service not found"));

        if (service.getProviderId() == null || !service.getProviderId().equals(provider.getId())) {
            throw new BadRequestException("You can only update your own services");
        }

        if (serviceEntityRepository.existsByProviderIdAndNameIgnoreCaseAndIdNot(provider.getId(), name, serviceId)) {
            throw new BadRequestException("You already have another service with this name");
        }

        service.setName(name);
        service.setPrice(request.getPrice());
        service.setDescription(description);

        return serviceEntityRepository.save(service);
    }

    public void deleteServiceByProvider(Long serviceId, Long providerId) {
        if (providerId == null) {
            throw new BadRequestException("providerId is required");
        }

        User provider = getValidatedProvider(providerId);

        ServiceEntity service = serviceEntityRepository.findById(serviceId)
                .orElseThrow(() -> new BadRequestException("Service not found"));

        if (service.getProviderId() == null || !service.getProviderId().equals(provider.getId())) {
            throw new BadRequestException("You can only delete your own services");
        }

        try {
            serviceEntityRepository.delete(service);
        } catch (DataIntegrityViolationException ex) {
            throw new BadRequestException("Cannot delete service with existing bookings");
        }
    }

    private void validateServicePayload(Long providerId, String name, Double price, String description) {
        if (providerId == null || name == null || price == null || description == null) {
            throw new BadRequestException("providerId, name, price and description are required");
        }

        if (name.trim().isEmpty() || description.trim().isEmpty()) {
            throw new BadRequestException("name and description cannot be empty");
        }

        if (price <= 0) {
            throw new BadRequestException("price must be greater than zero");
        }
    }

    private User getValidatedProvider(Long providerId) {
        User provider = userRepository.findById(providerId)
                .orElseThrow(() -> new BadRequestException("Provider not found"));

        if (provider.getRole() != Role.PROVIDER) {
            throw new BadRequestException("Only PROVIDER accounts can manage services");
        }

        return provider;
    }
}