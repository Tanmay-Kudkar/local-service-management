-- -----------------------------------------------------------------------------
-- users: stores application users (USER or PROVIDER)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL,
    contact_number VARCHAR(20),
    address VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    pincode VARCHAR(20),
    profile_image_url VARCHAR(600),
    profile_image_data BYTEA,
    profile_image_content_type VARCHAR(100),
    experience_years INTEGER,
    skills VARCHAR(500),
    bio VARCHAR(1000),
    verified BOOLEAN NOT NULL DEFAULT FALSE,
    rating_average DOUBLE PRECISION NOT NULL DEFAULT 0,
    total_reviews INTEGER NOT NULL DEFAULT 0,
    live_location_sharing_enabled BOOLEAN DEFAULT FALSE,
    live_latitude DOUBLE PRECISION,
    live_longitude DOUBLE PRECISION,
    live_location_updated_at TIMESTAMP,
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
    provider_id BIGINT,
    date DATE NOT NULL,
    status VARCHAR(30),
    tracking_note VARCHAR(255),
    live_location_sharing_enabled BOOLEAN DEFAULT FALSE,
    provider_latitude DOUBLE PRECISION,
    provider_longitude DOUBLE PRECISION,
    provider_location_updated_at TIMESTAMP,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    CONSTRAINT chk_booking_status CHECK (
        status IN ('PENDING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')
    ),
    CONSTRAINT fk_bookings_user
        FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_bookings_service
        FOREIGN KEY (service_id) REFERENCES services(id),
    CONSTRAINT fk_bookings_provider
        FOREIGN KEY (provider_id) REFERENCES users(id)
);

-- -----------------------------------------------------------------------------
-- reviews: stores customer ratings/reviews for completed bookings
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reviews (
    id BIGSERIAL PRIMARY KEY,
    booking_id BIGINT NOT NULL UNIQUE,
    user_id BIGINT NOT NULL,
    provider_id BIGINT NOT NULL,
    service_id BIGINT NOT NULL,
    rating INTEGER NOT NULL,
    comment VARCHAR(1000),
    provider_response VARCHAR(1000),
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    CONSTRAINT chk_review_rating CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT fk_reviews_booking
        FOREIGN KEY (booking_id) REFERENCES bookings(id),
    CONSTRAINT fk_reviews_user
        FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_reviews_provider
        FOREIGN KEY (provider_id) REFERENCES users(id),
    CONSTRAINT fk_reviews_service
        FOREIGN KEY (service_id) REFERENCES services(id)
);

-- -----------------------------------------------------------------------------
-- indexes: supports common query patterns in the API
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_service_id ON bookings(service_id);
CREATE INDEX IF NOT EXISTS idx_bookings_provider_id ON bookings(provider_id);
CREATE INDEX IF NOT EXISTS idx_bookings_date ON bookings(date);
CREATE INDEX IF NOT EXISTS idx_services_provider_id ON services(provider_id);
CREATE INDEX IF NOT EXISTS idx_reviews_provider_id ON reviews(provider_id);
CREATE INDEX IF NOT EXISTS idx_reviews_booking_id ON reviews(booking_id);