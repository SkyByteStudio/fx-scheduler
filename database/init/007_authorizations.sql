SET search_path TO scheduler, public;

INSERT INTO authorizations
(
code,
name
)
VALUES

(
'LINE',
'Line Maintenance'
),

(
'BASE',
'Base Maintenance'
),

(
'ENGINE',
'Engine Maintenance'
);