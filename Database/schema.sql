-- -----------------------------------------------------------------------------
-- users: stores application users (USER or PROVIDER)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL,
    CONSTRAINT chk_users_role CHECK (role IN ('USER', 'PROVIDER'))
);

-- -----------------------------------------------------------------------------
-- services: stores available services shown in the app
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS services (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price DOUBLE PRECISION NOT NULL,
    description VARCHAR(500),
    provider_id BIGINT,
    CONSTRAINT fk_services_provider
        FOREIGN KEY (provider_id) REFERENCES users(id)
);

-- -----------------------------------------------------------------------------
-- bookings: stores booking records linking users and services
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bookings (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    service_id BIGINT NOT NULL,
    date DATE NOT NULL,
    CONSTRAINT fk_bookings_user
        FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_bookings_service
        FOREIGN KEY (service_id) REFERENCES services(id)
);

-- -----------------------------------------------------------------------------
-- indexes: supports common query patterns in the API
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_service_id ON bookings(service_id);
CREATE INDEX IF NOT EXISTS idx_bookings_date ON bookings(date);
CREATE INDEX IF NOT EXISTS idx_services_provider_id ON services(provider_id);