BEGIN;

SET search_path TO scheduler, public;

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
    '0001',
    'Alex',
    'Morgan',
    'Aircraft Mechanic',
    'PERMANENT',
    DATE '2020-01-01',
    NULL,
    100.00,
    TRUE
),
(
    '0002',
    'Jamie',
    'Taylor',
    'Aircraft Mechanic',
    'PERMANENT',
    DATE '2020-01-01',
    DATE '2027-02-02',
    99.00,
    TRUE
),
(
    '0003',
    'Casey',
    'Reed',
    'Aircraft Mechanic',
    'PERMANENT',
    DATE '2021-03-01',
    NULL,
    98.00,
    TRUE
),
(
    '0004',
    'Jordan',
    'Blake',
    'Aircraft Mechanic',
    'PERMANENT',
    DATE '2020-01-01',
    DATE '2026-07-31',
    97.00,
    TRUE
),
(
    '0005',
    'Emma',
    'Clarke',
    'Aircraft Mechanic',
    'PERMANENT',
    DATE '2022-01-01',
    NULL,
    96.00,
    TRUE
),
(
    '0006',
    'Noah',
    'Bennett',
    'Aircraft Mechanic',
    'PERMANENT',
    DATE '2021-01-01',
    NULL,
    95.00,
    TRUE
),
(
    'A001',
    'Liam',
    'Foster',
    'Aircraft Mechanic',
    'CONTRACTOR',
    DATE '2022-01-01',
    DATE '2027-02-02',
    111.00,
    TRUE
),
(
    'A002',
    'Maya',
    'Collins',
    'Aircraft Mechanic',
    'CONTRACTOR',
    DATE '2023-01-01',
    DATE '2027-12-31',
    125.00,
    TRUE
),
(
    'A003',
    'Ethan',
    'Brooks',
    'Aircraft Mechanic',
    'CONTRACTOR',
    DATE '2024-01-01',
    DATE '2027-12-31',
    105.00,
    TRUE
),
(
    'A004',
    'Sofia',
    'Turner',
    'Aircraft Mechanic',
    'CONTRACTOR',
    DATE '2024-01-01',
    DATE '2027-12-31',
    108.00,
    TRUE
);

COMMIT;