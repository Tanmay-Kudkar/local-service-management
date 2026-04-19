INSERT INTO services (name, price)
SELECT 'Plumber', 500.0
WHERE NOT EXISTS (
    SELECT 1 FROM services WHERE name = 'Plumber'
);

INSERT INTO services (name, price)
SELECT 'Electrician', 700.0
WHERE NOT EXISTS (
    SELECT 1 FROM services WHERE name = 'Electrician'
);