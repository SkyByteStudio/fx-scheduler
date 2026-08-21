BEGIN;

CREATE OR REPLACE FUNCTION scheduler.get_employee_eligibility(
    p_contract_id BIGINT,
    p_work_date DATE,
    p_time_of_day VARCHAR
)
RETURNS TABLE
(
    employee_id BIGINT,
    employee_number VARCHAR,
    full_name TEXT,
    employee_position VARCHAR,
    contract_type VARCHAR,
    hourly_rate NUMERIC,

    employee_active BOOLEAN,
    employee_contract_valid BOOLEAN,
    customer_contract_valid BOOLEAN,
    station_preference_valid BOOLEAN,
    airport_permit_valid BOOLEAN,
    authorization_valid BOOLEAN,
    required_skill_valid BOOLEAN,
    absence_free BOOLEAN,

    eligible BOOLEAN,
    rejection_reasons TEXT[],

    contract_priority INTEGER,
    cost_priority NUMERIC
)
LANGUAGE sql
STABLE
AS
$$
WITH demand AS
(
    SELECT
        cd.id AS demand_id,
        cd.contract_id,
        cd.demand_date,
        cd.time_of_day,
        cd.skill_group_id,
        cd.category_id,
        cd.authorization_id,

        cc.station_id,
        cc.valid_from AS customer_contract_valid_from,
        cc.valid_to AS customer_contract_valid_to,
        cc.active AS customer_contract_active

    FROM scheduler.contract_demands cd

    JOIN scheduler.customer_contracts cc
        ON cc.id = cd.contract_id

    WHERE cd.contract_id = p_contract_id
      AND cd.demand_date = p_work_date
      AND cd.time_of_day = UPPER(p_time_of_day)
),
employee_checks AS
(
    SELECT
        e.id AS employee_id,
        e.employee_number,
        CONCAT_WS(' ', e.first_name, e.last_name) AS full_name,
        e.position AS employee_position,
        e.contract_type,
        e.hourly_rate,

        e.active AS employee_active,

        (
            e.contract_valid_from <= p_work_date
            AND (
                e.contract_valid_to IS NULL
                OR e.contract_valid_to >= p_work_date
            )
        ) AS employee_contract_valid,

        (
            d.customer_contract_active = TRUE
            AND d.customer_contract_valid_from <= p_work_date
            AND d.customer_contract_valid_to >= p_work_date
        ) AS customer_contract_valid,

        EXISTS
        (
            SELECT 1
            FROM scheduler.employee_station_preferences esp
            WHERE esp.employee_id = e.id
              AND esp.station_id = d.station_id
              AND esp.valid_from <= p_work_date
              AND (
                    esp.valid_to IS NULL
                    OR esp.valid_to >= p_work_date
              )
        ) AS station_preference_valid,

        EXISTS
        (
            SELECT 1
            FROM scheduler.employee_airport_permits eap
            WHERE eap.employee_id = e.id
              AND eap.station_id = d.station_id
              AND eap.valid_from <= p_work_date
              AND eap.valid_to >= p_work_date
        ) AS airport_permit_valid,

        (
            d.authorization_id IS NULL
            OR EXISTS
            (
                SELECT 1
                FROM scheduler.employee_authorizations ea
                WHERE ea.employee_id = e.id
                  AND ea.authorization_id = d.authorization_id
                  AND ea.valid_from <= p_work_date
                  AND ea.valid_to >= p_work_date
            )
        ) AS authorization_valid,

        EXISTS
        (
            SELECT 1
            FROM scheduler.employee_skills es
            WHERE es.employee_id = e.id
              AND es.skill_group_id = d.skill_group_id
              AND es.category_id = d.category_id
              AND es.valid_from <= p_work_date
              AND es.valid_to >= p_work_date
        ) AS required_skill_valid,

        NOT EXISTS
        (
            SELECT 1
            FROM scheduler.employee_absences eabs

            JOIN scheduler.absence_codes ac
                ON ac.id = eabs.absence_code_id

            WHERE eabs.employee_id = e.id
              AND ac.blocks_work = TRUE
              AND p_work_date BETWEEN eabs.date_from AND eabs.date_to
        ) AS absence_free

    FROM scheduler.employees e
    CROSS JOIN demand d
)
SELECT
    ec.employee_id,
    ec.employee_number,
    ec.full_name,
    ec.employee_position,
    ec.contract_type,
    ec.hourly_rate,

    ec.employee_active,
    ec.employee_contract_valid,
    ec.customer_contract_valid,
    ec.station_preference_valid,
    ec.airport_permit_valid,
    ec.authorization_valid,
    ec.required_skill_valid,
    ec.absence_free,

    (
        ec.employee_active
        AND ec.employee_contract_valid
        AND ec.customer_contract_valid
        AND ec.station_preference_valid
        AND ec.airport_permit_valid
        AND ec.authorization_valid
        AND ec.required_skill_valid
        AND ec.absence_free
    ) AS eligible,

    ARRAY_REMOVE(
        ARRAY[
            CASE
                WHEN NOT ec.employee_active
                THEN 'EMPLOYEE_INACTIVE'
            END,

            CASE
                WHEN NOT ec.employee_contract_valid
                THEN 'EMPLOYEE_CONTRACT_INVALID'
            END,

            CASE
                WHEN NOT ec.customer_contract_valid
                THEN 'CUSTOMER_CONTRACT_INVALID'
            END,

            CASE
                WHEN NOT ec.station_preference_valid
                THEN 'STATION_PREFERENCE_INVALID'
            END,

            CASE
                WHEN NOT ec.airport_permit_valid
                THEN 'AIRPORT_PERMIT_INVALID'
            END,

            CASE
                WHEN NOT ec.authorization_valid
                THEN 'AUTHORIZATION_INVALID'
            END,

            CASE
                WHEN NOT ec.required_skill_valid
                THEN 'REQUIRED_SKILL_INVALID'
            END,

            CASE
                WHEN NOT ec.absence_free
                THEN 'EMPLOYEE_ABSENT'
            END
        ],
        NULL
    ) AS rejection_reasons,

    CASE
        WHEN ec.contract_type = 'PERMANENT' THEN 1
        WHEN ec.contract_type = 'CONTRACTOR' THEN 2
        ELSE 99
    END AS contract_priority,

    ec.hourly_rate AS cost_priority

FROM employee_checks ec

ORDER BY
    eligible DESC,
    contract_priority,
    cost_priority,
    employee_number;
$$;

COMMENT ON FUNCTION scheduler.get_employee_eligibility(BIGINT, DATE, VARCHAR) IS
    'Evaluates employee eligibility for a contract demand on a specific date and time of day.';

COMMIT;
