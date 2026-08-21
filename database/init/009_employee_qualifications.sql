BEGIN;

SET search_path TO scheduler, public;

-- ============================================================
-- STATION PREFERENCES
-- ============================================================

INSERT INTO employee_station_preferences
(
    employee_id,
    station_id,
    valid_from,
    valid_to,
    is_default
)
SELECT
    e.id,
    s.id,
    DATE '2020-01-01',
    NULL,
    TRUE
FROM employees e
CROSS JOIN stations s
WHERE e.employee_number IN (
    '0001',
    '0002',
    '0003',
    '0004',
    '0005',
    '0006',
    'A001',
    'A002',
    'A003'
)
AND s.code = 'HUB1';

-- A004 prefers HUB2 rather than HUB1.
INSERT INTO employee_station_preferences
(
    employee_id,
    station_id,
    valid_from,
    valid_to,
    is_default
)
SELECT
    e.id,
    s.id,
    DATE '2020-01-01',
    NULL,
    TRUE
FROM employees e
CROSS JOIN stations s
WHERE e.employee_number = 'A004'
AND s.code = 'HUB2';

-- ============================================================
-- AIRPORT PERMITS
-- ============================================================

-- Valid HUB1 permits.
INSERT INTO employee_airport_permits
(
    employee_id,
    station_id,
    permit_number,
    valid_from,
    valid_to
)
SELECT
    e.id,
    s.id,
    'HUB1-' || e.employee_number,
    DATE '2025-01-01',
    DATE '2027-12-31'
FROM employees e
CROSS JOIN stations s
WHERE e.employee_number IN (
    '0001',
    '0002',
    '0003',
    '0004',
    '0006',
    'A001',
    'A002',
    'A003'
)
AND s.code = 'HUB1';

-- 0005 has an expired HUB1 permit.
INSERT INTO employee_airport_permits
(
    employee_id,
    station_id,
    permit_number,
    valid_from,
    valid_to
)
SELECT
    e.id,
    s.id,
    'HUB1-' || e.employee_number,
    DATE '2024-01-01',
    DATE '2026-07-31'
FROM employees e
CROSS JOIN stations s
WHERE e.employee_number = '0005'
AND s.code = 'HUB1';

-- A004 has a valid permit, but only for HUB2.
INSERT INTO employee_airport_permits
(
    employee_id,
    station_id,
    permit_number,
    valid_from,
    valid_to
)
SELECT
    e.id,
    s.id,
    'HUB2-' || e.employee_number,
    DATE '2025-01-01',
    DATE '2027-12-31'
FROM employees e
CROSS JOIN stations s
WHERE e.employee_number = 'A004'
AND s.code = 'HUB2';

-- ============================================================
-- AUTHORISATIONS
-- ============================================================

-- All employees have valid LINE authorisation.
INSERT INTO employee_authorizations
(
    employee_id,
    authorization_id,
    valid_from,
    valid_to
)
SELECT
    e.id,
    a.id,
    DATE '2025-01-01',
    DATE '2027-12-31'
FROM employees e
CROSS JOIN authorizations a
WHERE a.code = 'LINE';

-- ============================================================
-- AIRBUS A320 / CFM56 / B1 SKILLS
-- ============================================================

-- Valid required skill for most employees.
INSERT INTO employee_skills
(
    employee_id,
    skill_group_id,
    category_id,
    valid_from,
    valid_to
)
SELECT
    e.id,
    sg.id,
    c.id,
    DATE '2025-01-01',
    DATE '2027-12-31'
FROM employees e
CROSS JOIN skill_groups sg
CROSS JOIN categories c
WHERE e.employee_number IN (
    '0001',
    '0002',
    '0003',
    '0004',
    '0005',
    'A001',
    'A002',
    'A004'
)
AND sg.name = 'Airbus A320 CFM56'
AND c.code = 'B1';

-- 0006 has the correct skill, but it expired.
INSERT INTO employee_skills
(
    employee_id,
    skill_group_id,
    category_id,
    valid_from,
    valid_to
)
SELECT
    e.id,
    sg.id,
    c.id,
    DATE '2024-01-01',
    DATE '2026-07-31'
FROM employees e
CROSS JOIN skill_groups sg
CROSS JOIN categories c
WHERE e.employee_number = '0006'
AND sg.name = 'Airbus A320 CFM56'
AND c.code = 'B1';

-- A003 has the wrong aircraft qualification.
INSERT INTO employee_skills
(
    employee_id,
    skill_group_id,
    category_id,
    valid_from,
    valid_to
)
SELECT
    e.id,
    sg.id,
    c.id,
    DATE '2025-01-01',
    DATE '2027-12-31'
FROM employees e
CROSS JOIN skill_groups sg
CROSS JOIN categories c
WHERE e.employee_number = 'A003'
AND sg.name = 'Boeing 737 CFM'
AND c.code = 'B1';

COMMIT;