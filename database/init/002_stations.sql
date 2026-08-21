SET search_path TO scheduler, public;

-- Fully synthetic stations used by the portfolio demo.
INSERT INTO stations
(code, name, country_code)
VALUES
('HUB1', 'Central Hub Airport', 'AA'),
('HUB2', 'North Hub Airport', 'AA'),
('HUB3', 'Coastal Hub Airport', 'AA'),
('HUB4', 'East Hub Airport', 'BB'),
('HUB5', 'North-East Hub Airport', 'CC');
