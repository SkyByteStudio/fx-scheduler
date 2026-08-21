SET search_path TO scheduler, public;

INSERT INTO absence_codes
(code, name)
VALUES

('A', 'Annual Leave'),
('L', 'Sickness'),
('K', 'Business Trip');