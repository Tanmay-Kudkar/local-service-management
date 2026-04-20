package com.lsm.backend.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;

import com.lsm.backend.dto.ServiceCatalogItemResponse;
import com.lsm.backend.entity.BookingStatus;
import com.lsm.backend.dto.ServiceCreateRequest;
import com.lsm.backend.dto.ServiceUpdateRequest;
import com.lsm.backend.entity.Role;
import com.lsm.backend.entity.ServiceEntity;
import com.lsm.backend.entity.User;
import com.lsm.backend.exception.BadRequestException;
import com.lsm.backend.repository.BookingRepository;
import com.lsm.backend.repository.ServiceEntityRepository;
import com.lsm.backend.repository.UserRepository;

@Service
public class ServiceCatalogService {

    private static final List<BookingStatus> BLOCKING_BOOKING_STATUSES = List.of(
            BookingStatus.PENDING,
            BookingStatus.CONFIRMED,
            BookingStatus.IN_PROGRESS);

    private final ServiceEntityRepository serviceEntityRepository;
    private final UserRepository userRepository;
    private final BookingRepository bookingRepository;

    public ServiceCatalogService(
            ServiceEntityRepository serviceEntityRepository,
            UserRepository userRepository,
            BookingRepository bookingRepository) {
        this.serviceEntityRepository = serviceEntityRepository;
        this.userRepository = userRepository;
        this.bookingRepository = bookingRepository;
    }

    public List<ServiceEntity> getAllServices() {
        return serviceEntityRepository.findAll();
    }

    public List<ServiceCatalogItemResponse> getAllServicesForCatalog() {
        return getAllServicesForCatalog(null, null, null, null, null, null, false, null);
    }

    public List<ServiceCatalogItemResponse> getAllServicesForCatalog(
            Double minPrice,
            Double maxPrice,
            Double minRating,
            Double maxDistanceKm,
            Double userLatitude,
            Double userLongitude,
            Boolean onlyAvailable,
            LocalDate availableDate) {
        if (minPrice != null && maxPrice != null && minPrice > maxPrice) {
            throw new BadRequestException("minPrice cannot be greater than maxPrice");
        }

        if (minRating != null && (minRating < 0 || minRating > 5)) {
            throw new BadRequestException("minRating must be between 0 and 5");
        }

        if (maxDistanceKm != null && maxDistanceKm <= 0) {
            throw new BadRequestException("maxDistanceKm must be greater than zero");
        }

        if ((userLatitude == null) != (userLongitude == null)) {
            throw new BadRequestException("userLatitude and userLongitude must be provided together");
        }

        if (userLatitude != null && (userLatitude < -90 || userLatitude > 90)) {
            throw new BadRequestException("userLatitude must be between -90 and 90");
        }

        if (userLongitude != null && (userLongitude < -180 || userLongitude > 180)) {
            throw new BadRequestException("userLongitude must be between -180 and 180");
        }

        boolean requireAvailability = Boolean.TRUE.equals(onlyAvailable);
        LocalDate availabilityDate = requireAvailability && availableDate == null
            ? LocalDate.now()
            : availableDate;

        List<ServiceEntity> services = serviceEntityRepository.findAll();

        Set<Long> providerIds = services.stream()
                .map(ServiceEntity::getProviderId)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());

        Map<Long, User> providersById = userRepository.findAllById(providerIds).stream()
                .collect(Collectors.toMap(User::getId, provider -> provider));

        return services.stream()
                .map(service -> toCatalogItem(
                        service,
                        providersById.get(service.getProviderId()),
                        userLatitude,
                        userLongitude,
                        availabilityDate))
                .filter(item -> minPrice == null || item.getPrice() >= minPrice)
                .filter(item -> maxPrice == null || item.getPrice() <= maxPrice)
                .filter(item -> minRating == null || item.getProviderRatingAverage() >= minRating)
                .filter(item -> {
                    if (maxDistanceKm == null) {
                        return true;
                    }
                    return item.getProviderDistanceKm() != null && item.getProviderDistanceKm() <= maxDistanceKm;
                })
                .filter(item -> !requireAvailability || defaultBoolean(item.getAvailable()))
                .toList();
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

    private ServiceCatalogItemResponse toCatalogItem(
            ServiceEntity service,
            User provider,
            Double userLatitude,
            Double userLongitude,
            LocalDate availabilityDate) {
        boolean providerLiveSharing = provider != null && defaultBoolean(provider.getLiveLocationSharingEnabled());
        Double providerLatitude = provider == null ? null : provider.getLiveLatitude();
        Double providerLongitude = provider == null ? null : provider.getLiveLongitude();
        Double distanceKm = null;

        if (providerLiveSharing
                && providerLatitude != null
                && providerLongitude != null
                && userLatitude != null
                && userLongitude != null) {
            distanceKm = calculateDistanceKm(userLatitude, userLongitude, providerLatitude, providerLongitude);
        }

        boolean available = availabilityDate == null || isServiceAvailable(service.getId(), availabilityDate);

        return new ServiceCatalogItemResponse(
                service.getId(),
                service.getName(),
                service.getPrice(),
                service.getDescription(),
                service.getProviderId(),
                provider == null ? null : provider.getName(),
                provider == null ? null : provider.getContactNumber(),
                provider == null ? null : provider.getAddress(),
                provider == null ? null : provider.getCity(),
                provider == null ? null : provider.getState(),
                provider == null ? null : provider.getPincode(),
                provider == null ? null : provider.getProfileImageUrl(),
                provider == null ? null : encodeImageBase64(provider.getProfileImageData()),
                provider == null ? null : provider.getProfileImageContentType(),
                provider == null ? null : provider.getExperienceYears(),
                provider == null ? null : provider.getSkills(),
                provider == null ? null : provider.getBio(),
                provider == null ? false : defaultBoolean(provider.getVerified()),
                provider == null ? 0.0 : defaultDouble(provider.getRatingAverage()),
                provider == null ? 0 : defaultInteger(provider.getTotalReviews()),
                providerLiveSharing,
                providerLatitude,
                providerLongitude,
                provider == null ? null : toIsoString(provider.getLiveLocationUpdatedAt()),
                distanceKm,
                available);
    }

    private boolean defaultBoolean(Boolean value) {
        return value != null && value;
    }

    private double defaultDouble(Double value) {
        return value == null ? 0.0 : value;
    }

    private int defaultInteger(Integer value) {
        return value == null ? 0 : value;
    }

    private boolean isServiceAvailable(Long serviceId, LocalDate date) {
        return !bookingRepository.existsByServiceIdAndDateAndStatusIn(serviceId, date, BLOCKING_BOOKING_STATUSES);
    }

    private String encodeImageBase64(byte[] imageData) {
        if (imageData == null) {
            return null;
        }
        return Base64.getEncoder().encodeToString(imageData);
    }

    private String toIsoString(LocalDateTime dateTime) {
        return dateTime == null ? null : dateTime.toString();
    }

    private double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
        double earthRadiusKm = 6371.0;

        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);

        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                        * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

        return earthRadiusKm * c;
    }
}