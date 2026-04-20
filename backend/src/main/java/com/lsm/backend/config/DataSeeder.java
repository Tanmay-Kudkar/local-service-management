package com.lsm.backend.config;

import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import com.lsm.backend.entity.ServiceEntity;
import com.lsm.backend.repository.ServiceEntityRepository;

@Component
public class DataSeeder implements CommandLineRunner {

    private final ServiceEntityRepository serviceEntityRepository;

    public DataSeeder(ServiceEntityRepository serviceEntityRepository) {
        this.serviceEntityRepository = serviceEntityRepository;
    }

    @Override
    public void run(String... args) {
        seedServiceIfMissing("Plumber", 500.0);
        seedServiceIfMissing("Electrician", 700.0);
    }

    private void seedServiceIfMissing(String name, double price) {
        if (serviceEntityRepository.existsByName(name)) {
            return;
        }

        ServiceEntity service = new ServiceEntity();
        service.setName(name);
        service.setPrice(price);
        serviceEntityRepository.save(service);
    }
}