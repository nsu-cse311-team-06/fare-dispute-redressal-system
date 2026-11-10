-- =====================================================================
-- CSE311L | Team 06 | Section 3
-- Project: Public Transport Fare Dispute Redressal System
-- Database script (Compatible with MySQL 8.0.16+ and MariaDB 10.4+)
-- Contents: Schema, Constraints, Triggers, Views, Sample Data, Test Queries
-- =====================================================================

DROP DATABASE IF EXISTS fare_dispute_db;
CREATE DATABASE fare_dispute_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE fare_dispute_db;

-- =====================================================================
-- 1. TABLES
-- =====================================================================

-- 1.1 USER: passengers and admins
CREATE TABLE `USER` (
    user_id        INT AUTO_INCREMENT,
    full_name      VARCHAR(100) NOT NULL,
    email          VARCHAR(100) NOT NULL,
    password_hash  VARCHAR(255) NOT NULL,
    phone          VARCHAR(15),
    role           ENUM('Passenger','Admin') NOT NULL DEFAULT 'Passenger',
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_user PRIMARY KEY (user_id),
    CONSTRAINT uq_user_email UNIQUE (email)
) ENGINE=InnoDB;

-- 1.2 BUS_OPERATOR: companies/owners operating bus lines
CREATE TABLE BUS_OPERATOR (
    operator_id    INT AUTO_INCREMENT,
    operator_name  VARCHAR(100) NOT NULL,
    license_no     VARCHAR(50)  NOT NULL,
    contact_phone  VARCHAR(15),
    status         ENUM('Active','Suspended') NOT NULL DEFAULT 'Active',
    CONSTRAINT pk_operator PRIMARY KEY (operator_id),
    CONSTRAINT uq_operator_license UNIQUE (license_no)
) ENGINE=InnoDB;

-- 1.3 BUS: individual bus belonging to an operator
CREATE TABLE BUS (
    bus_id       INT AUTO_INCREMENT,
    bus_number   VARCHAR(20) NOT NULL,
    bus_type     VARCHAR(30),
    operator_id  INT NOT NULL,
    CONSTRAINT pk_bus PRIMARY KEY (bus_id),
    CONSTRAINT uq_bus_number UNIQUE (bus_number),
    CONSTRAINT fk_bus_operator FOREIGN KEY (operator_id)
        REFERENCES BUS_OPERATOR (operator_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 1.4 ROUTE: approved start and end points
CREATE TABLE ROUTE (
    route_id     INT AUTO_INCREMENT,
    route_name   VARCHAR(100) NOT NULL,
    origin       VARCHAR(100) NOT NULL,
    destination  VARCHAR(100) NOT NULL,
    CONSTRAINT pk_route PRIMARY KEY (route_id),
    CONSTRAINT uq_route_name UNIQUE (route_name)
) ENGINE=InnoDB;

-- 1.5 STOP: individual bus stops
CREATE TABLE STOP (
    stop_id    INT AUTO_INCREMENT,
    stop_name  VARCHAR(100) NOT NULL,
    area       VARCHAR(100),
    CONSTRAINT pk_stop PRIMARY KEY (stop_id)
) ENGINE=InnoDB;

-- 1.6 ROUTE_STOP: junction table for INCLUDES (M:N between ROUTE and STOP)
CREATE TABLE ROUTE_STOP (
    route_id    INT NOT NULL,
    stop_id     INT NOT NULL,
    stop_order  INT NOT NULL,
    CONSTRAINT pk_route_stop PRIMARY KEY (route_id, stop_id),
    CONSTRAINT uq_route_stop_order UNIQUE (route_id, stop_order),
    CONSTRAINT fk_rs_route FOREIGN KEY (route_id)
        REFERENCES ROUTE (route_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_rs_stop FOREIGN KEY (stop_id)
        REFERENCES STOP (stop_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_rs_order CHECK (stop_order > 0)
) ENGINE=InnoDB;

-- 1.7 FARE: approved fare between boarding and destination stops on a route
CREATE TABLE FARE (
    fare_id         INT AUTO_INCREMENT,
    route_id        INT NOT NULL,
    from_stop_id    INT NOT NULL,
    to_stop_id      INT NOT NULL,
    approved_fare   DECIMAL(8,2) NOT NULL,
    effective_from  DATE NOT NULL,
    effective_to    DATE NULL,                 -- NULL = currently active
    managed_by      INT NOT NULL,              -- Admin who recorded this fare
    -- Note: from_stop_id <> to_stop_id is enforced by triggers (MySQL does not allow a
    -- CHECK on FK columns that use ON UPDATE CASCADE).
    CONSTRAINT pk_fare PRIMARY KEY (fare_id),
    CONSTRAINT uq_fare UNIQUE (route_id, from_stop_id, to_stop_id, effective_from),
    CONSTRAINT fk_fare_route FOREIGN KEY (route_id)
        REFERENCES ROUTE (route_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_fare_from FOREIGN KEY (from_stop_id)
        REFERENCES STOP (stop_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_fare_to FOREIGN KEY (to_stop_id)
        REFERENCES STOP (stop_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_fare_admin FOREIGN KEY (managed_by)
        REFERENCES `USER` (user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_fare_amount CHECK (approved_fare >= 0),
    CONSTRAINT chk_fare_dates  CHECK (effective_to IS NULL OR effective_to >= effective_from)
) ENGINE=InnoDB;

-- 1.8 COMPLAINT: passenger overcharge reports
-- Note: fare_difference is derived (computed in v_complaint_details), not stored.
CREATE TABLE COMPLAINT (
    complaint_id     INT AUTO_INCREMENT,
    tracking_number  VARCHAR(20) NOT NULL DEFAULT '',
    passenger_id     INT NOT NULL,
    bus_id           INT NOT NULL,
    fare_id          INT NOT NULL,
    journey_date     DATE NOT NULL,
    journey_time     TIME,
    amount_paid      DECIMAL(8,2) NOT NULL,
    description      TEXT,
    status           ENUM('Pending','Under Review','Resolved','Rejected')
                     NOT NULL DEFAULT 'Pending',
    filed_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_complaint PRIMARY KEY (complaint_id),
    CONSTRAINT uq_complaint_tracking UNIQUE (tracking_number),
    CONSTRAINT fk_complaint_passenger FOREIGN KEY (passenger_id)
        REFERENCES `USER` (user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_complaint_bus FOREIGN KEY (bus_id)
        REFERENCES BUS (bus_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_complaint_fare FOREIGN KEY (fare_id)
        REFERENCES FARE (fare_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_complaint_amount CHECK (amount_paid > 0)
) ENGINE=InnoDB;

-- 1.9 COMPLAINT_PHOTO: optional photo evidence
CREATE TABLE COMPLAINT_PHOTO (
    photo_id      INT AUTO_INCREMENT,
    complaint_id  INT NOT NULL,
    file_path     VARCHAR(255) NOT NULL,
    uploaded_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_photo PRIMARY KEY (photo_id),
    CONSTRAINT fk_photo_complaint FOREIGN KEY (complaint_id)
        REFERENCES COMPLAINT (complaint_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 1.10 COMPLAINT_REVIEW: full decision audit history
CREATE TABLE COMPLAINT_REVIEW (
    review_id     INT AUTO_INCREMENT,
    complaint_id  INT NOT NULL,
    admin_id      INT NOT NULL,
    decision      ENUM('Under Review','Resolved','Rejected') NOT NULL,
    remarks       TEXT,
    reviewed_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_review PRIMARY KEY (review_id),
    CONSTRAINT fk_review_complaint FOREIGN KEY (complaint_id)
        REFERENCES COMPLAINT (complaint_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_review_admin FOREIGN KEY (admin_id)
        REFERENCES `USER` (user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- 2. INDEXES (for frequently queried foreign keys & lookup filters)
-- =====================================================================
CREATE INDEX idx_complaint_status    ON COMPLAINT (status);
CREATE INDEX idx_complaint_passenger ON COMPLAINT (passenger_id);
CREATE INDEX idx_complaint_bus       ON COMPLAINT (bus_id);
CREATE INDEX idx_complaint_fare      ON COMPLAINT (fare_id);
CREATE INDEX idx_fare_lookup         ON FARE (route_id, from_stop_id, to_stop_id);
CREATE INDEX idx_review_complaint    ON COMPLAINT_REVIEW (complaint_id);

-- =====================================================================
-- 3. TRIGGERS
-- =====================================================================
DELIMITER //

-- 3.1 FARE: managed_by must be Admin; both stops must belong to the route
CREATE TRIGGER trg_fare_bi
BEFORE INSERT ON FARE
FOR EACH ROW
BEGIN
    IF NEW.from_stop_id = NEW.to_stop_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Boarding stop and destination stop must be different';
    END IF;

    IF (SELECT role FROM `USER` WHERE user_id = NEW.managed_by) <> 'Admin' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'FARE.managed_by must reference a user with role Admin';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM ROUTE_STOP
                   WHERE route_id = NEW.route_id AND stop_id = NEW.from_stop_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Boarding stop does not belong to this route';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM ROUTE_STOP
                   WHERE route_id = NEW.route_id AND stop_id = NEW.to_stop_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Destination stop does not belong to this route';
    END IF;
END//

CREATE TRIGGER trg_fare_bu
BEFORE UPDATE ON FARE
FOR EACH ROW
BEGIN
    IF NEW.from_stop_id = NEW.to_stop_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Boarding stop and destination stop must be different';
    END IF;

    IF (SELECT role FROM `USER` WHERE user_id = NEW.managed_by) <> 'Admin' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'FARE.managed_by must reference a user with role Admin';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM ROUTE_STOP
                   WHERE route_id = NEW.route_id AND stop_id = NEW.from_stop_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Boarding stop does not belong to this route';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM ROUTE_STOP
                   WHERE route_id = NEW.route_id AND stop_id = NEW.to_stop_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Destination stop does not belong to this route';
    END IF;
END//

-- 3.2 COMPLAINT: auto tracking number, passenger check, journey date within fare validity
CREATE TRIGGER trg_complaint_bi
BEFORE INSERT ON COMPLAINT
FOR EACH ROW
BEGIN
    DECLARE v_from DATE;
    DECLARE v_to   DATE;

    -- Generate tracking number if empty or null (e.g. FD-261110-A3F9C2, 16 chars)
    IF NEW.tracking_number IS NULL OR NEW.tracking_number = '' THEN
        SET NEW.tracking_number = CONCAT(
            'FD-', DATE_FORMAT(NOW(), '%y%m%d'), '-',
            UPPER(SUBSTRING(REPLACE(UUID(), '-', ''), 1, 6)));
    END IF;

    -- Only users with role 'Passenger' can file complaints
    IF (SELECT role FROM `USER` WHERE user_id = NEW.passenger_id) <> 'Passenger' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Only users with role Passenger can file complaints';
    END IF;

    -- Journey date must fall inside the linked fare record's validity period
    SELECT effective_from, effective_to INTO v_from, v_to
    FROM FARE WHERE fare_id = NEW.fare_id;

    IF NEW.journey_date < v_from OR (v_to IS NOT NULL AND NEW.journey_date > v_to) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Journey date is outside the effective period of the linked fare';
    END IF;

    SET NEW.status = 'Pending';
END//

CREATE TRIGGER trg_complaint_bu
BEFORE UPDATE ON COMPLAINT
FOR EACH ROW
BEGIN
    DECLARE v_from DATE;
    DECLARE v_to   DATE;

    -- Maintain passenger role check
    IF (SELECT role FROM `USER` WHERE user_id = NEW.passenger_id) <> 'Passenger' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Only users with role Passenger can file complaints';
    END IF;

    SELECT effective_from, effective_to INTO v_from, v_to
    FROM FARE WHERE fare_id = NEW.fare_id;

    IF NEW.journey_date < v_from OR (v_to IS NOT NULL AND NEW.journey_date > v_to) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Journey date is outside the effective period of the linked fare';
    END IF;
END//

-- 3.3 COMPLAINT_REVIEW: reviewer must be Admin; sync COMPLAINT.status
CREATE TRIGGER trg_review_bi
BEFORE INSERT ON COMPLAINT_REVIEW
FOR EACH ROW
BEGIN
    IF (SELECT role FROM `USER` WHERE user_id = NEW.admin_id) <> 'Admin' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'COMPLAINT_REVIEW.admin_id must reference a user with role Admin';
    END IF;
END//

CREATE TRIGGER trg_review_bu
BEFORE UPDATE ON COMPLAINT_REVIEW
FOR EACH ROW
BEGIN
    IF (SELECT role FROM `USER` WHERE user_id = NEW.admin_id) <> 'Admin' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'COMPLAINT_REVIEW.admin_id must reference a user with role Admin';
    END IF;
END//

CREATE TRIGGER trg_review_ai
AFTER INSERT ON COMPLAINT_REVIEW
FOR EACH ROW
BEGIN
    UPDATE COMPLAINT
    SET status = NEW.decision
    WHERE complaint_id = NEW.complaint_id;
END//

DELIMITER ;

-- =====================================================================
-- 4. VIEWS (derived attributes + analytical reports)
-- =====================================================================

-- 4.1 Complaint details with derived fare_difference
CREATE VIEW v_complaint_details AS
SELECT  c.complaint_id,
        c.tracking_number,
        u.full_name        AS passenger_name,
        r.route_name,
        sf.stop_name       AS boarding_stop,
        st.stop_name       AS destination_stop,
        b.bus_number,
        bo.operator_name,
        c.journey_date,
        c.journey_time,
        f.approved_fare,
        c.amount_paid,
        (c.amount_paid - f.approved_fare) AS fare_difference,   -- derived attribute
        c.status,
        c.filed_at
FROM COMPLAINT c
JOIN `USER` u         ON u.user_id      = c.passenger_id
JOIN BUS b            ON b.bus_id       = c.bus_id
JOIN BUS_OPERATOR bo  ON bo.operator_id = b.operator_id
JOIN FARE f           ON f.fare_id      = c.fare_id
JOIN ROUTE r          ON r.route_id     = f.route_id
JOIN STOP sf          ON sf.stop_id     = f.from_stop_id
JOIN STOP st          ON st.stop_id     = f.to_stop_id;

-- 4.2 Repeat offenders: complaints & total overcharge per operator
-- Uses GREATEST(..., 0) so non-overcharge complaints don't introduce negative offsets
CREATE VIEW v_operator_complaints AS
SELECT  bo.operator_id,
        bo.operator_name,
        bo.status                         AS operator_status,
        COUNT(c.complaint_id)             AS total_complaints,
        SUM(GREATEST(c.amount_paid - f.approved_fare, 0)) AS total_overcharge
FROM BUS_OPERATOR bo
JOIN BUS b       ON b.operator_id = bo.operator_id
JOIN COMPLAINT c ON c.bus_id      = b.bus_id
JOIN FARE f      ON f.fare_id     = c.fare_id
GROUP BY bo.operator_id, bo.operator_name, bo.status;

-- 4.3 Most disputed routes with average overcharge
CREATE VIEW v_route_disputes AS
SELECT  r.route_id,
        r.route_name,
        COUNT(c.complaint_id)                AS total_complaints,
        AVG(GREATEST(c.amount_paid - f.approved_fare, 0)) AS avg_overcharge
FROM ROUTE r
JOIN FARE f      ON f.route_id = r.route_id
JOIN COMPLAINT c ON c.fare_id  = f.fare_id
GROUP BY r.route_id, r.route_name;

-- 4.4 Current fare lookup helper (strictly currently active fares)
CREATE VIEW v_current_fares AS
SELECT  f.fare_id,
        r.route_name,
        sf.stop_name AS boarding_stop,
        st.stop_name AS destination_stop,
        f.approved_fare,
        f.effective_from
FROM FARE f
JOIN ROUTE r  ON r.route_id  = f.route_id
JOIN STOP sf  ON sf.stop_id  = f.from_stop_id
JOIN STOP st  ON st.stop_id  = f.to_stop_id
WHERE f.effective_from <= CURDATE()
  AND (f.effective_to IS NULL OR f.effective_to >= CURDATE());

-- =====================================================================
-- 5. SAMPLE DATA
-- =====================================================================

-- 5.1 Users (2 Admins, 3 Passengers)
INSERT INTO `USER` (full_name, email, password_hash, phone, role) VALUES
('Admin One',      'admin1@fareapp.com',  '$2b$10$dummyhashadmin1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', '01700000001', 'Admin'),
('Admin Two',      'admin2@fareapp.com',  '$2b$10$dummyhashadmin2xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', '01700000002', 'Admin'),
('Rahim Uddin',    'rahim@example.com',   '$2b$10$dummyhashpass1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', '01811111111', 'Passenger'),
('Nusrat Jahan',   'nusrat@example.com',  '$2b$10$dummyhashpass2xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', '01822222222', 'Passenger'),
('Karim Hossain',  'karim@example.com',   '$2b$10$dummyhashpass3xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', '01833333333', 'Passenger');

-- 5.2 Bus Operators
INSERT INTO BUS_OPERATOR (operator_name, license_no, contact_phone, status) VALUES
('Raida Paribahan',   'LIC-DHK-1001', '01911000001', 'Active'),
('Balaka Transport',  'LIC-DHK-1002', '01911000002', 'Active'),
('Anabil Enterprise', 'LIC-DHK-1003', '01911000003', 'Active');

-- 5.3 Buses
INSERT INTO BUS (bus_number, bus_type, operator_id) VALUES
('Dhaka Metro-BA-11-1234', 'Local',   1),
('Dhaka Metro-BA-11-5678', 'AC',      1),
('Dhaka Metro-HA-13-4321', 'Local',   2),
('Dhaka Metro-CHA-15-9876','Express', 3);

-- 5.4 Routes
INSERT INTO ROUTE (route_name, origin, destination) VALUES
('Mirpur-10 to Motijheel', 'Mirpur-10', 'Motijheel'),
('Uttara to Gulistan',     'Uttara',    'Gulistan');

-- 5.5 Stops
INSERT INTO STOP (stop_name, area) VALUES
('Mirpur-10', 'Mirpur'),              -- 1
('Agargaon',  'Sher-e-Bangla Nagar'), -- 2
('Farmgate',  'Tejgaon'),             -- 3
('Shahbag',   'Ramna'),               -- 4
('Motijheel', 'Motijheel'),           -- 5
('Uttara',    'Uttara'),              -- 6
('Gulistan',  'Gulistan');            -- 7

-- 5.6 Route Stops (Route 1: Mirpur-10 -> Agargaon -> Farmgate -> Shahbag -> Motijheel)
INSERT INTO ROUTE_STOP (route_id, stop_id, stop_order) VALUES
(1, 1, 1), (1, 2, 2), (1, 3, 3), (1, 4, 4), (1, 5, 5);

-- Route Stops (Route 2: Uttara -> Mirpur-10 -> Farmgate -> Shahbag -> Gulistan)
INSERT INTO ROUTE_STOP (route_id, stop_id, stop_order) VALUES
(2, 6, 1), (2, 1, 2), (2, 3, 3), (2, 4, 4), (2, 7, 5);

-- 5.7 Fares (recorded by Admin 1 & Admin 2)
INSERT INTO FARE (route_id, from_stop_id, to_stop_id, approved_fare, effective_from, effective_to, managed_by) VALUES
(1, 1, 5, 40.00, '2026-01-01', NULL, 1),   -- fare_id 1: Mirpur-10 -> Motijheel
(1, 1, 3, 25.00, '2026-01-01', NULL, 1),   -- fare_id 2: Mirpur-10 -> Farmgate
(1, 3, 5, 20.00, '2026-01-01', NULL, 2),   -- fare_id 3: Farmgate  -> Motijheel
(2, 6, 7, 45.00, '2026-01-01', NULL, 2),   -- fare_id 4: Uttara    -> Gulistan
(2, 1, 4, 25.00, '2026-01-01', NULL, 1);   -- fare_id 5: Mirpur-10 -> Shahbag

-- 5.8 Complaints
-- (tracking_number generated automatically by trigger; status initialized to 'Pending')
INSERT INTO COMPLAINT (tracking_number, passenger_id, bus_id, fare_id, journey_date, journey_time, amount_paid, description) VALUES
('', 3, 1, 1, '2026-10-20', '08:30:00', 60.00, 'Conductor demanded 60 BDT for Mirpur-10 to Motijheel (approved is 40).'),
('', 4, 3, 2, '2026-10-22', '17:45:00', 25.00, 'Fare was correct but bus was extremely crowded.'),
('', 5, 1, 4, '2026-10-25', '09:10:00', 70.00, 'Charged 70 BDT for Uttara to Gulistan (approved is 45).'),
('', 3, 4, 3, '2026-11-02', '19:00:00', 35.00, 'Charged 35 instead of 20 from Farmgate to Motijheel.');

-- 5.9 Complaint Photos
INSERT INTO COMPLAINT_PHOTO (complaint_id, file_path) VALUES
(1, '/uploads/complaints/1/ticket_001.jpg'),
(1, '/uploads/complaints/1/bus_front_002.jpg'),
(3, '/uploads/complaints/3/ticket_003.jpg');

-- 5.10 Reviews (trg_review_ai automatically syncs COMPLAINT.status to the review decision)
INSERT INTO COMPLAINT_REVIEW (complaint_id, admin_id, decision, remarks) VALUES
(1, 1, 'Under Review', 'Verifying fare chart and contacting operator.'),
(1, 1, 'Resolved',     'Overcharge confirmed. Operator warned, 20 BDT refund arranged.'),
(2, 2, 'Rejected',     'Amount paid matches approved fare; no overcharge.');

-- =====================================================================
-- 6. VERIFICATION & DEMO TEST QUERIES
-- =====================================================================

-- a) Fare lookup: check approved fare between Mirpur-10 and Motijheel
-- SELECT * FROM v_current_fares WHERE route_name = 'Mirpur-10 to Motijheel';

-- b) Complaint tracking & overcharge calculation:
-- SELECT tracking_number, passenger_name, route_name, bus_number, approved_fare, amount_paid, fare_difference, status
-- FROM v_complaint_details;

-- c) Analytical Report 1: Repeat offender operators:
-- SELECT * FROM v_operator_complaints ORDER BY total_complaints DESC;

-- d) Analytical Report 2: Most disputed routes:
-- SELECT * FROM v_route_disputes ORDER BY total_complaints DESC;

-- e) Audit trail: Complaint decision history:
-- SELECT c.tracking_number, u.full_name AS admin_name, cr.decision, cr.remarks, cr.reviewed_at
-- FROM COMPLAINT_REVIEW cr
-- JOIN COMPLAINT c ON c.complaint_id = cr.complaint_id
-- JOIN `USER` u    ON u.user_id      = cr.admin_id
-- ORDER BY cr.reviewed_at;

-- f) Business Constraint Tests (Demonstrates error handling):
-- 1. Fails: Passenger attempting to review a complaint (Requires Admin):
--    INSERT INTO COMPLAINT_REVIEW (complaint_id, admin_id, decision) VALUES (3, 3, 'Resolved');
-- 2. Fails: Boarding stop equals destination stop (trigger trg_fare_bi):
--    INSERT INTO FARE (route_id, from_stop_id, to_stop_id, approved_fare, effective_from, managed_by) VALUES (1, 1, 1, 10, '2026-01-01', 1);
-- 3. Fails: Journey date outside effective fare range:
--    INSERT INTO COMPLAINT (passenger_id, bus_id, fare_id, journey_date, amount_paid) VALUES (3, 1, 1, '2025-01-01', 50);
