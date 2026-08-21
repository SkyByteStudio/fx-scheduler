SET search_path TO scheduler, public;

INSERT INTO shifts
(
    shift_code,
    name,
    time_of_day,
    start_time,
    end_time,
    break_start_time,
    break_end_time,
    work_hours
)
VALUES

(
'D8',
'Day Shift',
'DAY',
'08:00',
'17:00',
'12:00',
'13:00',
8
),

(
'N8',
'Night Shift',
'NIGHT',
'20:00',
'05:00',
'00:00',
'01:00',
8
);