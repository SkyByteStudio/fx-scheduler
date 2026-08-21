# Aviation Workforce Scheduler Optimisation (MVP)

> Independent aviation workforce scheduling portfolio prototype demonstrating deterministic optimisation, workflow automation and operational reporting.

---

# Project Status

**Current Version:** MVP v1

The project demonstrates deterministic workforce optimisation using Google OR-Tools together with workflow automation and business reporting.

The primary objective is to automate workforce scheduling and rapidly regenerate schedules after operational disruptions while respecting business constraints.

The current implementation successfully demonstrates the complete scheduling workflow from schedule generation through absence reporting and automatic regeneration.

---

# Business Problem

Aircraft maintenance workforce scheduling is a highly constrained optimisation problem.

Every employee assignment must satisfy multiple business rules before an engineer can be allocated to customer work.

Typical operational disruptions include:

- employee sickness
- annual leave
- business trips
- qualification expiry
- airport permit expiry
- authorisation expiry
- changing customer demand

Traditionally these changes require manual schedule updates.

This prototype demonstrates how deterministic optimisation can automate that process.

---

# Solution Overview

The solution combines:

- Google OR-Tools deterministic optimisation
- Business rule validation
- Workflow automation
- Schedule regeneration
- Management reporting
- Complete audit trail

Unlike generative AI, the optimiser always produces deterministic and reproducible schedules.

---

# Why Google OR-Tools?

Google OR-Tools is widely used for optimisation problems including:

- workforce scheduling
- airline operations
- logistics
- manufacturing
- resource allocation

For aviation maintenance planning, deterministic optimisation provides predictable and explainable scheduling decisions that can be audited.

The optimisation engine evaluates thousands of possible employee assignments before selecting the lowest-cost valid schedule.

---

# Business Rules Implemented

The scheduler validates:

✅ Employee is active

✅ Employment contract valid

✅ Airport permit valid

✅ Required aircraft qualification valid

✅ Required authorisation valid

✅ Employee not absent

✅ Employee available for requested planning date

✅ Permanent employees preferred

✅ Contractors used only when required

✅ Lowest contractor hourly rate selected first

✅ Customer demand satisfied

✅ Labour cost minimised

---

# Demonstrated Workflows

## P1 — Generate Workforce Schedule

Manager requests schedule generation.

System:

- validates employee eligibility
- evaluates workforce availability
- generates optimal schedule
- minimises labour cost
- produces management report

Result:

✔ Successful workforce schedule

---

## P2 — Report Employee Absence & Regenerate Schedule

Manager reports employee sickness.

System automatically:

- records employee absence
- preserves original schedule
- creates linked regeneration run
- removes unavailable employee
- reallocates workforce
- recalculates labour cost
- produces regeneration report

Result:

✔ New schedule generated automatically

✔ Full audit trail maintained

---

# Current Features

The MVP currently includes:

### Database

- workforce master data
- employee qualifications
- airport permits
- employee authorisations
- absence management
- customer contracts
- optimisation history
- schedule assignments

---

### Optimisation Engine

- Google OR-Tools
- deterministic solver
- eligibility validation
- labour cost optimisation
- permanent-first allocation
- contractor fallback
- demand coverage validation

---

### Workflow Automation

- Schedule generation workflow

- Employee absence workflow

- Automatic schedule regeneration

- Report generation

---

### Reporting

Interactive HTML reports including:

- optimisation summary
- KPIs
- workforce allocation
- demand coverage
- labour cost
- regeneration summary
- disruption audit information


# Installation

## Prerequisites

The current MVP has been developed and tested on Ubuntu Linux using Docker.

Required software:

- Docker Desktop or Docker Engine
- Docker Compose
- Git

---

# Clone Repository

```bash
git clone https://github.com/SkyByteStudio/fx-scheduler.git
cd fx-scheduler
```

---

# Project Structure

```
fx-scheduler/

database/
    init/
        SQL schema
        Demo data

optimizer/
    FastAPI + Google OR-Tools

n8n/
    workflows/
    javascript/

docker-compose.yaml
.env.example
README.md
```

---

# Configure Environment

Create the local environment file from the public-safe template.

```bash
cp .env.example .env
```

---

# Start Environment

Start all required services.

```bash
docker compose up -d
```

The following containers will start:

| Service | Port |
|----------|------|
| PostgreSQL | 5434 |
| n8n | 5679 |
| Optimizer API | 8001 |

Verify:

```bash
docker ps
```

---

# Database Initialisation

The PostgreSQL container automatically executes every SQL file located in

```
database/init/
```

during the first startup.

The scripts create:

- scheduler schema
- reference tables
- employee data
- customer contract
- optimisation functions
- demo scenario

If rebuilding the database:

```bash
docker compose down -v
docker compose up -d
```

---

# Access n8n

Open

```
http://localhost:5679
```

Import the workflows located in

```
n8n/workflows/
```

Current workflows

- P2 - Generate Workforce Schedule
- P2 - Report Absence and Regenerate Schedule

---

# Optimizer API

FastAPI runs on

```
http://localhost:8001
```


# Useful Commands

Restart containers

```bash
docker compose restart
```

Stop environment

```bash
docker compose down
```

Recreate database

```bash
docker compose down -v
docker compose up -d
```

View logs

```bash
docker compose logs -f
```

Optimizer logs

```bash
docker compose logs -f optimizer
```

---

# Screenshots

Example screenshots are available in

```
screenshots/
```

---

# Videos

Example videos are available in

```
videos/
```


---

---

# Database Schema

## Overview

The workforce scheduler is built around a relational PostgreSQL database that models the business entities required for deterministic workforce optimisation.

Rather than storing only employees and schedules, the schema separates business rules, qualifications, operational constraints and optimisation results. This allows every generated schedule to be fully reproducible and auditable.

The optimisation engine validates employee eligibility before Google OR-Tools attempts to build an optimal schedule.

---

# Schema Overview

```
Employees
      │
      ├──────────────┐
      │              │
      ▼              ▼
Qualifications   Authorisations
      │              │
      └──────┬───────┘
             │
             ▼
      Employee Eligibility
             │
             ▼
      Customer Demand
             │
             ▼
     Google OR-Tools Solver
             │
             ▼
      Schedule Runs
             │
             ▼
     Schedule Assignments
```

---

# Core Reference Tables

## 001_schema.sql

Creates the `scheduler` database schema together with all required PostgreSQL objects used by the optimisation engine.

This script serves as the database foundation for the entire application.

---

## 002_stations

Stores all maintenance stations (airports) where work can be performed.

Example values

| Code | Station |
|------|---------|
| HUB1 | Central Hub |
| HUB2 | North Hub |
| HUB4 | East Hub |

Business purpose

- Defines where engineers may work.
- Used when validating airport permits.
- Used by customer contracts.

---

## 003_shifts

Defines every supported work shift.

Example

| Code | Description |
|------|-------------|
| D8 | 8 Hour Day Shift |
| N8 | 8 Hour Night Shift |

Each shift stores

- shift code
- day/night indicator
- start time
- end time
- break duration
- working hours
- active status

Business purpose

Provides standardised shift definitions for schedule generation.

---

## 004_absence_codes

Master list of employee absence types.

Current examples

| Code | Description |
|------|-------------|
| L | Sick Leave |
| A | Annual Leave |
| K | Business Trip |

Business purpose

Allows new absence types to be added without modifying optimisation logic.

---

## 005_categories

Aircraft certification categories.

Examples

- A1
- B1
- B2

Business purpose

Represents engineer certification levels required by customer contracts.

---

## 006_skill_groups

Defines aircraft maintenance skill groups.

Example hierarchy

Manufacturer

- Boeing
- Airbus

Aircraft Family

- 737
- A320

Engine

- CFM56
- LEAP

Business purpose

Determines which engineers are qualified to work on a specific aircraft.

---

## 007_authorizations

Stores operational authorisations held by engineers.

Examples

- Engine Run
- Taxi Approval
- Fuel Tank Entry

Each authorisation contains validity dates.

Business purpose

Only valid authorisations may be used during schedule generation.

---

# Workforce Tables

## 008_employees

Master employee table.

Stores

- Employee Number
- Full Name
- Employment Type
- Default Station
- Preferred Station
- Hourly Rate

Employment types

- Permanent
- Contractor

Business purpose

Represents the workforce available for scheduling.

The optimisation engine always attempts to allocate permanent employees before contractors.

---

## 009_employee_qualifications

Links employees with aircraft qualifications.

Stores

- Aircraft skill
- Category
- Valid From
- Valid Until

Business purpose

Determines whether an engineer may legally work on a specific aircraft.

---

## 010_employee_absences

Stores planned and unplanned employee absences.

Examples

- Sick leave
- Annual leave
- Business travel

Business purpose

Employees with active absences are automatically excluded from optimisation.

This table also enables automatic schedule regeneration.

---

# Customer Planning

## 011_demo_contract

Represents customer maintenance work requiring staffing.

Stores

- Customer
- Station
- Planning dates
- Required labour hours
- Required aircraft qualification

Business purpose

Represents demand that must be satisfied by the optimisation engine.

---

# Business Rule Engine

## 012_employee_eligibility

Core eligibility validation function.

This is the central business rule engine.

Before optimisation every employee is validated against all operational constraints.

Checks include

- Active employee
- Valid employment contract
- Airport permit
- Aircraft qualification
- Operational authorisations
- Employee absence
- Planning date validity

Returns

- Eligible = TRUE/FALSE
- Rejection reasons

Business purpose

Ensures only legally eligible engineers are passed into Google OR-Tools.

---

## 013_feasible_scenario

Creates repeatable demonstration data.

Generates

- Customer demand
- Candidate employees
- Planning scenario

Business purpose

Provides deterministic demo scenarios for testing and demonstrations.

---

# Runtime Tables

The following tables are automatically populated by the optimisation engine.

---

## customer_demands

Stores staffing demand for every planning period.

Contains

- Date
- Shift
- Required Hours

Business purpose

Represents optimisation targets.

---

## schedule_runs

Stores every optimisation execution.

Each generated schedule receives a unique Run ID.

Stores

- Optimisation Status
- Solver Result
- Labour Cost
- Trigger Reason
- Parent Run
- Planning Dates
- Execution Time

Business purpose

Provides a complete optimisation audit trail.

Example

```
Run 5
Manager generated schedule

↓

Employee reports sick

↓

Run 10
Automatically regenerated schedule
```

---

## schedule_assignments

Final optimisation result.

Contains one record for every employee assigned to work.

Stores

- Employee
- Shift
- Working Hours
- Labour Cost
- Schedule Run

Business purpose

Represents the published workforce schedule.

---

# Optimisation Workflow

The scheduling engine follows the following business process.

```
Employee Master Data
            │
            ▼
Aircraft Qualifications
            │
            ▼
Operational Authorisations
            │
            ▼
Employee Absences
            │
            ▼
Eligibility Validation
            │
            ▼
Customer Demand
            │
            ▼
Google OR-Tools Optimiser
            │
            ▼
Optimal Workforce Schedule
            │
            ▼
Management Reports
```


---

# Current Progress

## Completed

✅ Database design

✅ Workforce master data

✅ Employee eligibility validation

✅ Customer demand modelling

✅ Google OR-Tools integration

✅ Optimisation API

✅ Initial schedule generation

✅ Employee absence registration

✅ Automatic schedule regeneration

✅ Labour cost optimisation

✅ HTML management reports

✅ Workflow automation using n8n

---

## Planned Improvements

The architecture is intentionally modular and will continue to evolve.

Planned enhancements include:

- monthly planning horizon
- multiple stations
- multiple customer contracts
- overtime optimisation
- employee preferences
- fatigue management
- leave forecasting
- qualification expiry forecasting
- manager dashboard
- AI assistant explaining optimisation decisions
- Docker one-command installation
- automated integration tests
- architecture documentation
- demonstration videos

---

# Technology (Current MVP)

- Google OR-Tools
- Python
- FastAPI
- PostgreSQL
- SQL
- n8n
- JavaScript
- HTML reporting
- Docker

---

# Notes

This repository represents a business-focused proof of concept.

The optimisation logic is intentionally deterministic.

Artificial Intelligence is intended to assist workflow orchestration and explain optimisation results, while scheduling decisions remain fully deterministic through Google OR-Tools.


# Disclaimer

This project is an independent portfolio proof of concept using fully synthetic demonstration data.

All company names, station identifiers, employee records, customer contracts and demonstration data in this repository are synthetic. Business rules are simplified while preserving the core optimisation workflow.