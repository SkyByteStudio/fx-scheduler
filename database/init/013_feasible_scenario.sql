BEGIN;

SET search_path TO scheduler, public;

-- ============================================================
-- ADDITIONAL EMPLOYEES FOR THE FEASIBLE SCENARIO
-- ============================================================

INSERT INTO employees
(
    employee_number,
    first_name,
    last_name,
    position,
    contract_type,
    contract_valid_from,
    contract_valid_to,
    hourly_rate,
    active
)
VALUES
(
    '0007',
    'David',
    'Miller',
    'Aircraft Mechanic',
    'PERMANENT',
    DATE '2020-01-01',
    NULL,
    94.00,
    TRUE
),
(
    '0008',
    'Laura',
    'Wilson',
    'Aircraft Mechanic',
    'PERMANENT',
    DATE '2021-01-01',
    NULL,
    93.00,
    TRUE
),
(
    '0009',
    'Robert',
    'Brown',
    'Aircraft Mechanic',
    'PERMANENT',
    DATE '2022-01-01',
    NULL,
    92.00,
    TRUE
),
(
    '0010',
    'Emily',
    'Davis',
    'Aircraft Mechanic',
    'PERMANENT',
    DATE '2023-01-01',
    NULL,
    91.00,
    TRUE
),
(
    'A005',
    'Mark',
    'Taylor',
    'Aircraft Mechanic',
    'CONTRACTOR',
    DATE '2024-01-01',
    DATE '2027-12-31',
    115.00,
    TRUE
);

-- ============================================================
-- HUB1 STATION PREFERENCES
-- Valid only from 2026-08-04, preserving the infeasible
-- scenario on 2026-08-03.
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
    DATE '2026-08-04',
    NULL,
    TRUE
FROM employees e
CROSS JOIN stations s
WHERE e.employee_number IN (
    '0007',
    '0008',
    '0009',
    '0010',
    'A005'
)
AND s.code = 'HUB1';

-- ============================================================
-- VALID HUB1 AIRPORT PERMITS
-- ============================================================

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
    DATE '2026-08-04',
    DATE '2027-12-31'
FROM employees e
CROSS JOIN stations s
WHERE e.employee_number IN (
    '0007',
    '0008',
    '0009',
    '0010',
    'A005'
)
AND s.code = 'HUB1';

-- ============================================================
-- VALID LINE AUTHORISATIONS
-- ============================================================

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
    DATE '2026-08-04',
    DATE '2027-12-31'
FROM employees e
CROSS JOIN authorizations a
WHERE e.employee_number IN (
    '0007',
    '0008',
    '0009',
    '0010',
    'A005'
)
AND a.code = 'LINE';

-- ============================================================
-- VALID AIRBUS A320 / CFM56 / B1 SKILLS
-- ============================================================

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
    DATE '2026-08-04',
    DATE '2027-12-31'
FROM employees e
CROSS JOIN skill_groups sg
CROSS JOIN categories c
WHERE e.employee_number IN (
    '0007',
    '0008',
    '0009',
    '0010',
    'A005'
)
AND sg.name = 'Airbus A320 CFM56'
AND c.code = 'B1';

-- ============================================================
-- KEEP 0003 UNAVAILABLE FOR SCENARIO 2
--
-- 0003 was sick only on 2026-08-03 in the original scenario.
-- This additional absence prevents 0003 from becoming another
-- eligible permanent employee on 2026-08-04.
-- ============================================================

INSERT INTO employee_absences
(
    employee_id,
    absence_code_id,
    date_from,
    date_to,
    notes
)
SELECT
    e.id,
    ac.id,
    DATE '2026-08-04',
    DATE '2026-08-04',
    'Additional sickness day for feasible scenario test'
FROM employees e
CROSS JOIN absence_codes ac
WHERE e.employee_number = '0003'
AND ac.code = 'L';

-- ============================================================
-- FEASIBLE DEMAND: 2026-08-04
-- ============================================================

INSERT INTO contract_demands
(
    contract_id,
    demand_date,
    time_of_day,
    required_hours,
    skill_group_id,
    category_id,
    authorization_id,
    tolerance_percent
)
SELECT
    cc.id,
    DATE '2026-08-04',
    'DAY',
    40.00,
    sg.id,
    c.id,
    a.id,
    5.00
FROM customer_contracts cc
CROSS JOIN skill_groups sg
CROSS JOIN categories c
CROSS JOIN authorizations a
WHERE cc.contract_reference = 'DEMO-AIR-HUB1-2026'
  AND sg.name = 'Airbus A320 CFM56'
  AND c.code = 'B1'
  AND a.code = 'LINE';

INSERT INTO contract_demands
(
    contract_id,
    demand_date,
    time_of_day,
    required_hours,
    skill_group_id,
    category_id,
    authorization_id,
    tolerance_percent
)
SELECT
    cc.id,
    DATE '2026-08-04',
    'NIGHT',
    16.00,
    sg.id,
    c.id,
    a.id,
    5.00
FROM customer_contracts cc
CROSS JOIN skill_groups sg
CROSS JOIN categories c
CROSS JOIN authorizations a
WHERE cc.contract_reference = 'DEMO-AIR-HUB1-2026'
  AND sg.name = 'Airbus A320 CFM56'
  AND c.code = 'B1'
  AND a.code = 'LINE';

COMMIT;