-- Run from backend folder with:
-- psql -U postgres -d postgres -f scripts/bootstrap_db.sql

SELECT 'CREATE DATABASE lsm_db'
WHERE NOT EXISTS (
    SELECT FROM pg_database WHERE datname = 'lsm_db'
)\gexec

\connect lsm_db

CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS services (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    price DOUBLE PRECISION NOT NULL
);

CREATE TABLE IF NOT EXISTS bookings (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    service_id BIGINT NOT NULL,
    date DATE NOT NULL,
    CONSTRAINT fk_booking_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_booking_service FOREIGN KEY (service_id) REFERENCES services(id)
);

INSERT INTO services (name, price)
VALUES
    ('Plumber', 500.0),
    ('Electrician', 700.0)
ON CONFLICT (name) DO NOTHING;