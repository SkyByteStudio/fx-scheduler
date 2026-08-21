BEGIN;

CREATE SCHEMA IF NOT EXISTS scheduler;

COMMENT ON SCHEMA scheduler IS
    'Aviation workforce scheduling and optimisation data';

SET search_path TO scheduler, public;

-- ============================================================
-- REFERENCE / MASTER DATA
-- ============================================================

CREATE TABLE stations (
    id              BIGSERIAL PRIMARY KEY,
    code            VARCHAR(10) NOT NULL UNIQUE,
    name            VARCHAR(150) NOT NULL,
    country_code    CHAR(2),
    active          BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT stations_code_not_blank
        CHECK (BTRIM(code) <> ''),

    CONSTRAINT stations_name_not_blank
        CHECK (BTRIM(name) <> '')
);

CREATE TABLE employees (
    id                  BIGSERIAL PRIMARY KEY,
    employee_number     VARCHAR(20) NOT NULL UNIQUE,
    first_name          VARCHAR(100) NOT NULL,
    last_name           VARCHAR(100) NOT NULL,
    position            VARCHAR(100) NOT NULL,

    contract_type       VARCHAR(20) NOT NULL,
    contract_valid_from DATE NOT NULL,
    contract_valid_to   DATE,

    hourly_rate         NUMERIC(10, 2) NOT NULL,
    active              BOOLEAN NOT NULL DEFAULT TRUE,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT employees_contract_type_check
        CHECK (contract_type IN ('PERMANENT', 'CONTRACTOR')),

    CONSTRAINT employees_hourly_rate_check
        CHECK (hourly_rate >= 0),

    CONSTRAINT employees_contract_dates_check
        CHECK (
            contract_valid_to IS NULL
            OR contract_valid_to >= contract_valid_from
        ),

    CONSTRAINT employees_number_not_blank
        CHECK (BTRIM(employee_number) <> '')
);

CREATE TABLE shifts (
    id                  BIGSERIAL PRIMARY KEY,
    shift_code          VARCHAR(20) NOT NULL UNIQUE,
    name                VARCHAR(100) NOT NULL,
    time_of_day         VARCHAR(10) NOT NULL,

    start_time          TIME NOT NULL,
    end_time            TIME NOT NULL,
    break_start_time    TIME,
    break_end_time      TIME,

    work_hours          NUMERIC(5, 2) NOT NULL,
    active              BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT shifts_time_of_day_check
        CHECK (time_of_day IN ('DAY', 'NIGHT')),

    CONSTRAINT shifts_work_hours_check
        CHECK (work_hours > 0 AND work_hours <= 24),

    CONSTRAINT shifts_break_check
        CHECK (
            (break_start_time IS NULL AND break_end_time IS NULL)
            OR
            (break_start_time IS NOT NULL AND break_end_time IS NOT NULL)
        )
);

CREATE TABLE absence_codes (
    id              BIGSERIAL PRIMARY KEY,
    code            VARCHAR(10) NOT NULL UNIQUE,
    name            VARCHAR(100) NOT NULL,
    blocks_work     BOOLEAN NOT NULL DEFAULT TRUE,
    active          BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE categories (
    id              BIGSERIAL PRIMARY KEY,
    code            VARCHAR(20) NOT NULL UNIQUE,
    name            VARCHAR(100) NOT NULL,
    active          BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE skill_groups (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    manufacturer    VARCHAR(100) NOT NULL,
    aircraft_family VARCHAR(100),
    aircraft_type   VARCHAR(100),
    engine          VARCHAR(100),
    active          BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT skill_groups_unique_definition
        UNIQUE (
            manufacturer,
            aircraft_family,
            aircraft_type,
            engine
        )
);

CREATE TABLE authorizations (
    id              BIGSERIAL PRIMARY KEY,
    code            VARCHAR(50) NOT NULL UNIQUE,
    name            VARCHAR(150) NOT NULL,
    description     TEXT,
    active          BOOLEAN NOT NULL DEFAULT TRUE
);

-- ============================================================
-- EMPLOYEE QUALIFICATIONS AND AVAILABILITY
-- ============================================================

CREATE TABLE employee_station_preferences (
    id              BIGSERIAL PRIMARY KEY,
    employee_id     BIGINT NOT NULL
                        REFERENCES employees(id)
                        ON DELETE CASCADE,
    station_id      BIGINT NOT NULL
                        REFERENCES stations(id)
                        ON DELETE CASCADE,

    valid_from      DATE NOT NULL,
    valid_to        DATE,
    is_default      BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT employee_station_preference_dates_check
        CHECK (valid_to IS NULL OR valid_to >= valid_from),

    CONSTRAINT employee_station_preference_unique
        UNIQUE (employee_id, station_id, valid_from)
);

CREATE TABLE employee_airport_permits (
    id              BIGSERIAL PRIMARY KEY,
    employee_id     BIGINT NOT NULL
                        REFERENCES employees(id)
                        ON DELETE CASCADE,
    station_id      BIGINT NOT NULL
                        REFERENCES stations(id)
                        ON DELETE CASCADE,

    permit_number   VARCHAR(100),
    valid_from      DATE NOT NULL,
    valid_to        DATE NOT NULL,

    CONSTRAINT employee_airport_permit_dates_check
        CHECK (valid_to >= valid_from),

    CONSTRAINT employee_airport_permit_unique
        UNIQUE (employee_id, station_id, valid_from)
);

CREATE TABLE employee_authorizations (
    id                  BIGSERIAL PRIMARY KEY,
    employee_id         BIGINT NOT NULL
                            REFERENCES employees(id)
                            ON DELETE CASCADE,
    authorization_id    BIGINT NOT NULL
                            REFERENCES authorizations(id)
                            ON DELETE RESTRICT,

    valid_from          DATE NOT NULL,
    valid_to            DATE NOT NULL,

    CONSTRAINT employee_authorization_dates_check
        CHECK (valid_to >= valid_from),

    CONSTRAINT employee_authorization_unique
        UNIQUE (employee_id, authorization_id, valid_from)
);

CREATE TABLE employee_skills (
    id              BIGSERIAL PRIMARY KEY,
    employee_id     BIGINT NOT NULL
                        REFERENCES employees(id)
                        ON DELETE CASCADE,
    skill_group_id  BIGINT NOT NULL
                        REFERENCES skill_groups(id)
                        ON DELETE RESTRICT,
    category_id     BIGINT NOT NULL
                        REFERENCES categories(id)
                        ON DELETE RESTRICT,

    valid_from      DATE NOT NULL,
    valid_to        DATE NOT NULL,

    CONSTRAINT employee_skill_dates_check
        CHECK (valid_to >= valid_from),

    CONSTRAINT employee_skill_unique
        UNIQUE (
            employee_id,
            skill_group_id,
            category_id,
            valid_from
        )
);

CREATE TABLE employee_absences (
    id                  BIGSERIAL PRIMARY KEY,
    employee_id         BIGINT NOT NULL
                            REFERENCES employees(id)
                            ON DELETE CASCADE,
    absence_code_id     BIGINT NOT NULL
                            REFERENCES absence_codes(id)
                            ON DELETE RESTRICT,

    date_from           DATE NOT NULL,
    date_to             DATE NOT NULL,
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT employee_absence_dates_check
        CHECK (date_to >= date_from)
);

-- ============================================================
-- CUSTOMER CONTRACTS AND DEMAND
-- ============================================================

CREATE TABLE customer_contracts (
    id                  BIGSERIAL PRIMARY KEY,
    customer_name       VARCHAR(200) NOT NULL,
    contract_reference  VARCHAR(100) NOT NULL UNIQUE,
    station_id          BIGINT NOT NULL
                            REFERENCES stations(id)
                            ON DELETE RESTRICT,

    valid_from          DATE NOT NULL,
    valid_to            DATE NOT NULL,
    active              BOOLEAN NOT NULL DEFAULT TRUE,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT customer_contract_dates_check
        CHECK (valid_to >= valid_from)
);

CREATE TABLE contract_demands (
    id                  BIGSERIAL PRIMARY KEY,
    contract_id         BIGINT NOT NULL
                            REFERENCES customer_contracts(id)
                            ON DELETE CASCADE,

    demand_date         DATE NOT NULL,
    time_of_day         VARCHAR(10) NOT NULL,
    required_hours      NUMERIC(8, 2) NOT NULL,

    skill_group_id      BIGINT NOT NULL
                            REFERENCES skill_groups(id)
                            ON DELETE RESTRICT,
    category_id         BIGINT NOT NULL
                            REFERENCES categories(id)
                            ON DELETE RESTRICT,
    authorization_id    BIGINT
                            REFERENCES authorizations(id)
                            ON DELETE RESTRICT,

    tolerance_percent   NUMERIC(5, 2) NOT NULL DEFAULT 5.00,

    CONSTRAINT contract_demand_time_of_day_check
        CHECK (time_of_day IN ('DAY', 'NIGHT')),

    CONSTRAINT contract_demand_hours_check
        CHECK (required_hours >= 0),

    CONSTRAINT contract_demand_tolerance_check
        CHECK (
            tolerance_percent >= 0
            AND tolerance_percent <= 100
        ),

    CONSTRAINT contract_demand_unique
        UNIQUE (
            contract_id,
            demand_date,
            time_of_day,
            skill_group_id,
            category_id
        )
);

-- ============================================================
-- OPTIMISATION RUNS AND GENERATED SCHEDULES
-- ============================================================

CREATE TABLE schedule_runs (
    id                  BIGSERIAL PRIMARY KEY,
    parent_run_id       BIGINT
                            REFERENCES schedule_runs(id)
                            ON DELETE SET NULL,

    contract_id         BIGINT NOT NULL
                            REFERENCES customer_contracts(id)
                            ON DELETE RESTRICT,
    station_id          BIGINT NOT NULL
                            REFERENCES stations(id)
                            ON DELETE RESTRICT,

    planning_from       DATE NOT NULL,
    planning_to         DATE NOT NULL,

    status              VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    trigger_reason      TEXT,

    solver_status       VARCHAR(50),
    total_cost          NUMERIC(14, 2),
    execution_time_ms   BIGINT,

    started_at          TIMESTAMPTZ,
    completed_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT schedule_run_dates_check
        CHECK (planning_to >= planning_from),

    CONSTRAINT schedule_run_status_check
        CHECK (
            status IN (
                'PENDING',
                'RUNNING',
                'COMPLETED',
                'FAILED',
                'INFEASIBLE'
            )
        ),

    CONSTRAINT schedule_run_cost_check
        CHECK (total_cost IS NULL OR total_cost >= 0)
);

CREATE TABLE schedule_assignments (
    id                  BIGSERIAL PRIMARY KEY,
    schedule_run_id     BIGINT NOT NULL
                            REFERENCES schedule_runs(id)
                            ON DELETE CASCADE,

    employee_id         BIGINT NOT NULL
                            REFERENCES employees(id)
                            ON DELETE RESTRICT,
    contract_id         BIGINT NOT NULL
                            REFERENCES customer_contracts(id)
                            ON DELETE RESTRICT,
    station_id          BIGINT NOT NULL
                            REFERENCES stations(id)
                            ON DELETE RESTRICT,
    shift_id            BIGINT NOT NULL
                            REFERENCES shifts(id)
                            ON DELETE RESTRICT,

    work_date           DATE NOT NULL,
    assigned_hours      NUMERIC(5, 2) NOT NULL,
    hourly_rate         NUMERIC(10, 2) NOT NULL,
    assignment_cost     NUMERIC(12, 2) NOT NULL,

    selection_reason    TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT schedule_assignment_hours_check
        CHECK (assigned_hours > 0 AND assigned_hours <= 24),

    CONSTRAINT schedule_assignment_rate_check
        CHECK (hourly_rate >= 0),

    CONSTRAINT schedule_assignment_cost_check
        CHECK (assignment_cost >= 0),

    CONSTRAINT schedule_assignment_one_shift_per_day
        UNIQUE (schedule_run_id, employee_id, work_date)
);

CREATE TABLE schedule_run_metrics (
    id                      BIGSERIAL PRIMARY KEY,
    schedule_run_id         BIGINT NOT NULL
                                REFERENCES schedule_runs(id)
                                ON DELETE CASCADE,

    demand_date             DATE NOT NULL,
    time_of_day             VARCHAR(10) NOT NULL,

    required_hours          NUMERIC(8, 2) NOT NULL,
    scheduled_hours         NUMERIC(8, 2) NOT NULL,
    coverage_percent        NUMERIC(8, 2),

    permanent_hours         NUMERIC(8, 2) NOT NULL DEFAULT 0,
    contractor_hours        NUMERIC(8, 2) NOT NULL DEFAULT 0,

    permanent_cost          NUMERIC(12, 2) NOT NULL DEFAULT 0,
    contractor_cost         NUMERIC(12, 2) NOT NULL DEFAULT 0,

    within_tolerance        BOOLEAN NOT NULL,
    warning                 TEXT,

    CONSTRAINT schedule_metric_time_of_day_check
        CHECK (time_of_day IN ('DAY', 'NIGHT')),

    CONSTRAINT schedule_metric_hours_check
        CHECK (
            required_hours >= 0
            AND scheduled_hours >= 0
            AND permanent_hours >= 0
            AND contractor_hours >= 0
        ),

    CONSTRAINT schedule_metric_cost_check
        CHECK (
            permanent_cost >= 0
            AND contractor_cost >= 0
        ),

    CONSTRAINT schedule_metric_unique
        UNIQUE (schedule_run_id, demand_date, time_of_day)
);

-- ============================================================
-- INDEXES USED BY ELIGIBILITY AND OPTIMISATION QUERIES
-- ============================================================

CREATE INDEX idx_employees_contract_validity
    ON employees (
        contract_valid_from,
        contract_valid_to,
        contract_type,
        active
    );

CREATE INDEX idx_employee_station_preferences_lookup
    ON employee_station_preferences (
        employee_id,
        station_id,
        valid_from,
        valid_to
    );

CREATE INDEX idx_employee_airport_permits_lookup
    ON employee_airport_permits (
        employee_id,
        station_id,
        valid_from,
        valid_to
    );

CREATE INDEX idx_employee_authorizations_lookup
    ON employee_authorizations (
        employee_id,
        authorization_id,
        valid_from,
        valid_to
    );

CREATE INDEX idx_employee_skills_lookup
    ON employee_skills (
        employee_id,
        skill_group_id,
        category_id,
        valid_from,
        valid_to
    );

CREATE INDEX idx_employee_absences_lookup
    ON employee_absences (
        employee_id,
        date_from,
        date_to
    );

CREATE INDEX idx_contract_demands_lookup
    ON contract_demands (
        contract_id,
        demand_date,
        time_of_day
    );

CREATE INDEX idx_schedule_assignments_run_date
    ON schedule_assignments (
        schedule_run_id,
        work_date
    );

CREATE INDEX idx_schedule_assignments_employee_date
    ON schedule_assignments (
        employee_id,
        work_date
    );

COMMIT;