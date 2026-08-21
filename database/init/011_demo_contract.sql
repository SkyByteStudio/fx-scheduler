BEGIN;

SET search_path TO scheduler, public;

INSERT INTO customer_contracts
(
    customer_name,
    contract_reference,
    station_id,
    valid_from,
    valid_to,
    active
)
SELECT
    'Example Aviation',
    'DEMO-AIR-HUB1-2026',
    s.id,
    DATE '2026-08-01',
    DATE '2026-08-31',
    TRUE
FROM stations s
WHERE s.code = 'HUB1';

-- Day demand: 40 hours.
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
    DATE '2026-08-03',
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

-- Night demand: 16 hours.
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
    DATE '2026-08-03',
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