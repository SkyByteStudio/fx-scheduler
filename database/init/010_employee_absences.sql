BEGIN;

SET search_path TO scheduler, public;

-- 0002 is on annual leave.
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
    DATE '2026-08-01',
    DATE '2026-08-05',
    'Planned annual leave'
FROM employees e
CROSS JOIN absence_codes ac
WHERE e.employee_number = '0002'
AND ac.code = 'A';

-- 0003 is sick on the scheduling date.
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
    DATE '2026-08-03',
    DATE '2026-08-03',
    'Reported sick'
FROM employees e
CROSS JOIN absence_codes ac
WHERE e.employee_number = '0003'
AND ac.code = 'L';

COMMIT;