SET search_path TO scheduler, public;

INSERT INTO skill_groups
(
name,
manufacturer,
aircraft_family,
aircraft_type,
engine
)
VALUES

(
'Airbus A320 CFM56',
'Airbus',
'A320',
'A320',
'CFM56-5B'
),

(
'Airbus A320 IAE',
'Airbus',
'A320',
'A320',
'IAE V2500'
),

(
'Boeing 737 CFM',
'Boeing',
'737',
'737-800',
'CFM56-7B'
),

(
'Embraer E190',
'Embraer',
'E190',
'E190',
'CF34'
);