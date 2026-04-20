package com.lsm.backend.config;

import org.springframework.boot.CommandLineRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.lsm.backend.entity.ServiceEntity;
import com.lsm.backend.repository.ServiceEntityRepository;

@Component
public class DataSeeder implements CommandLineRunner {

    private static final Logger LOGGER = LoggerFactory.getLogger(DataSeeder.class);

    private final ServiceEntityRepository serviceEntityRepository;
    private final JdbcTemplate jdbcTemplate;

    public DataSeeder(ServiceEntityRepository serviceEntityRepository, JdbcTemplate jdbcTemplate) {
        this.serviceEntityRepository = serviceEntityRepository;
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public void run(String... args) {
        dropLegacyServiceNameUniqueConstraint();

        seedServiceIfMissing(
                "Plumber",
                500.0,
                "Leak fixes, fittings, and urgent plumbing repairs");
        seedServiceIfMissing(
                "Electrician",
                700.0,
                "Switchboard, wiring, and appliance electrical support");
    }

    private void seedServiceIfMissing(String name, double price, String description) {
        if (serviceEntityRepository.existsByProviderIdIsNullAndNameIgnoreCase(name)) {
            return;
        }

        ServiceEntity service = new ServiceEntity();
        service.setName(name);
        service.setPrice(price);
        service.setDescription(description);
        service.setProviderId(null);
        serviceEntityRepository.save(service);
    }

    private void dropLegacyServiceNameUniqueConstraint() {
        try {
            jdbcTemplate.execute("""
                    DO $$
                    DECLARE constraint_name TEXT;
                    BEGIN
                        SELECT con.conname
                        INTO constraint_name
                        FROM pg_constraint con
                        JOIN pg_class rel ON rel.oid = con.conrelid
                        WHERE rel.relname = 'services'
                          AND con.contype = 'u'
                          AND pg_get_constraintdef(con.oid) ILIKE '%(name)%'
                        LIMIT 1;

                        IF constraint_name IS NOT NULL THEN
                            EXECUTE format('ALTER TABLE services DROP CONSTRAINT %I', constraint_name);
                        END IF;
                    END $$;
                    """);
        } catch (Exception ex) {
            LOGGER.warn("Could not drop legacy unique constraint on services.name: {}", ex.getMessage());
        }
    }
}