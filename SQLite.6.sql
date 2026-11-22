-- CARELOOP CLINICS — NO-SHOW GUARD
-- PART 2: SQL ANALYSIS
-- For SQLiteOnline: do not run CREATE DATABASE or USE. Select SQLite engine.
-- First create the tables, then run the Part 1 load_data.sql file.

-- TASK 2.1: TABLES
CREATE TABLE clinics (
    clinic_id VARCHAR(5) PRIMARY KEY,
    clinic_name VARCHAR(40) NOT NULL,
    city VARCHAR(20) NOT NULL,
    tier VARCHAR(10),
    latitude DECIMAL(8,4),
    longitude DECIMAL(8,4),
    temp_c DECIMAL(5,1)
);

CREATE TABLE appointments (
    appointment_id VARCHAR(8) PRIMARY KEY,
    patient_id VARCHAR(8) NOT NULL,
    clinic_id VARCHAR(5) NOT NULL,
    booked_on DATE,
    appt_date DATE,
    age INT,
    gender VARCHAR(1),
    distance_km DECIMAL(5,1),
    fee_inr INT,
    booking_channel VARCHAR(10),
    visit_type VARCHAR(12),
    reminder_sent VARCHAR(3),
    prior_no_shows INT,
    status VARCHAR(10),
    lead_days INT,
    no_show INT,
    FOREIGN KEY (clinic_id) REFERENCES clinics(clinic_id)
);

-- Run load_data.sql AFTER creating both tables.
-- Clinics must be inserted before appointments because of the foreign key.

-- Verify loaded row counts.
SELECT COUNT(*) AS clinic_count FROM clinics;

SELECT COUNT(*) AS appointment_count,
       SUM(no_show) AS no_show_count
FROM appointments;

-- Duplicate primary-key test: run this statement separately AFTER loading data.
-- It is expected to fail because A0001 already exists.
-- INSERT INTO appointments (appointment_id, patient_id, clinic_id)
-- VALUES ('A0001', 'P196', 'C05');
-- Record the exact error returned by your SQLOnline run below as a comment.
-- SQLiteOnline expected wording: UNIQUE constraint failed: appointments.appointment_id

O-SHOW RATE BY CLINIC (at least 95 appointments)
SELECT
    c.clinic_name,
    c.city,
    COUNT(*) AS appointments,
    SUM(a.no_show) AS no_shows,
    ROUND(100.0 * SUM(a.no_show) / COUNT(*), 1) AS no_show_pct
FROM appointments AS a
JOIN clinics AS c
    ON a.clinic_id = c.clinic_id
GROUP BY c.clinic_id, c.clinic_name, c.city
HAVING COUNT(*) >= 95
ORDER BY no_show_pct DESC;

-- TASK 2.2: ALL EIGHT CLINICS (remove the HAVING restriction)
SELECT
    c.clinic_name,
    c.city,
    COUNT(*) AS appointments,
    SUM(a.no_show) AS no_shows,
    ROUND(100.0 * SUM(a.no_show) / COUNT(*), 1) AS no_show_pct
FROM appointments AS a
JOIN clinics AS c
    ON a.clinic_id = c.clinic_id
GROUP BY c.clinic_id, c.clinic_name, c.city
ORDER BY no_show_pct DESC;

-- TASK 2.3: NO-SHOW RATE BY BOOKING LEAD-TIME BAND
SELECT
    CASE
        WHEN lead_days <= 7 THEN '1-7'
        WHEN lead_days <= 14 THEN '8-14'
        WHEN lead_days <= 30 THEN '15-30'
        ELSE '31+'
    END AS lead_band,
    COUNT(*) AS appointments,
    SUM(no_show) AS no_shows,
    ROUND(100.0 * SUM(no_show) / COUNT(*), 1) AS no_show_pct
FROM appointments
GROUP BY lead_band
ORDER BY MIN(lead_days);

-- TASK 2.4: MONTHLY TREND AND CHANGE IN PERCENTAGE POINTS
WITH monthly AS (
    SELECT
        SUBSTR(appt_date, 1, 7) AS month,
        COUNT(*) AS appointments,
        ROUND(100.0 * SUM(no_show) / COUNT(*), 1) AS no_show_pct
    FROM appointments
    GROUP BY SUBSTR(appt_date, 1, 7)
  ),
monthly_with_previous AS (
    SELECT
        month,
        appointments,
        no_show_pct,
        LAG(no_show_pct) OVER (ORDER BY month) AS previous_rate
    FROM monthly
)
SELECT
    month,
    appointments,
    no_show_pct,
    ROUND(no_show_pct - previous_rate, 1) AS change_percentage_points
FROM monthly_with_previous
ORDER BY month;

-- TASK 2.5: RANK CLINICS WITHIN EACH CITY AND COMPARE WITH OVERALL RATE
WITH clinic_rates AS (
    SELECT
        c.clinic_id,
        c.clinic_name AS clinic,
        c.city,
        ROUND(100.0 * SUM(a.no_show) / COUNT(*), 1) AS no_show_pct
    FROM appointments AS a
    JOIN clinics AS c
        ON a.clinic_id = c.clinic_id
    GROUP BY c.clinic_id, c.clinic_name, c.city
)
SELECT
    clinic,
    city,
    no_show_pct,
    RANK() OVER (PARTITION BY city ORDER BY no_show_pct DESC) AS rank_in_city,
    CASE
        WHEN no_show_pct > (SELECT 100.0 * SUM(no_show) / COUNT(*) FROM appointments) THEN 'above'
        WHEN no_show_pct < (SELECT 100.0 * SUM(no_show) / COUNT(*) FROM appointments) THEN 'below'
        ELSE 'equal'
    END AS vs_overall
FROM clinic_rates
ORDER BY city, rank_in_city;