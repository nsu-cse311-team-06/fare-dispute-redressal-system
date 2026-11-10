# 🚌 Public Transport Fare Dispute Redressal System

[![Database](https://img.shields.io/badge/Database-MySQL%208.0.16%2B%20%7C%20MariaDB%2010.4%2B-blue.svg)](https://www.mysql.com/)
[![Environment](https://img.shields.io/badge/Environment-XAMPP-orange.svg)](https://www.apachefriends.org/)
[![Course](https://img.shields.io/badge/Course-CSE311L%20Database%20Systems%20Lab-red.svg)](https://ece.northsouth.edu/courses/cse-311/)
[![Section](https://img.shields.io/badge/Section-03%20%7C%20Team%2006-green.svg)]()
[![Status](https://img.shields.io/badge/Status-Schema%20%26%20Demo%20Data%20Included-success.svg)]()

A relational database system for approved public-transport fare lookup, passenger overcharge complaints, complaint tracking, administrator review, and transport data analytics.

---

## 🏛️ Academic Information

- **Institution:** North South University (NSU)
- **Department:** Electrical & Computer Engineering (ECE)
- **Course:** CSE311L — Database Systems Lab
- **Section:** 03 | **Team:** Team 06
- **Faculty:** Ms. Tanzilah Noor Shabnam [TnS1]
- **Lab Instructor:** Md. Amanullah Shah

---

## 👥 Team Members and Roles

| Student Name | Student ID | Designated Project Role |
|---|---|---|
| **Md Sifat Jaman** | `223292****` | **Project Coordinator & Database Designer** — ERD, logical schema, documentation, and coordination. |
| **Sabbir Ahmed** | `221248****` | **Database Designer & Frontend Developer** — schema modeling, DDL implementation, and interface planning. |
| **Progna Thakur** | `241134****` | **Database Engineer & Backend Developer** — referential integrity, triggers, views, and backend connection. |
| **Tausif Taher** | `241143****` | **Database Administrator & System Tester** — test data, edge-case validation, and integrity testing. |

> Student ID digits are masked for privacy.

---

## 💡 Project Overview

The **Public Transport Fare Dispute Redressal System** stores route information, bus stops, bus operators, buses, approved fares, passenger complaints, evidence photos, and administrator review decisions.

The database supports the following workflow:

1. An administrator adds routes, stops, operators, buses, and approved fare records.
2. A passenger checks the approved fare for a route segment.
3. The passenger files a complaint when the amount paid is higher than the approved fare.
4. The database generates a unique tracking number.
5. An administrator reviews the complaint and records a decision.
6. The complaint status is automatically synchronized with the latest review.
7. Reports show disputed operators, routes, fare differences, and audit history.

### 🔄 System Workflow

```text
[Admin Configures Data] → [Passenger Checks Fare] → [Passenger Files Complaint]
                                                        ↓
[Analytics and Reports] ← [Status Synchronized] ← [Admin Reviews Complaint]
                                  ↑
                    [UUID-Derived Tracking Number]
```

The database handles validation and status transitions through foreign keys, constraints, and triggers.

---

## ✨ Core System Capabilities

### 👤 Role-Based User Management

The `USER` table supports two roles:

- **Passenger:** Files complaints and is associated with complaint records.
- **Admin:** Manages fares and records complaint reviews.

Triggers verify that only users with the `Admin` role can manage fares and reviews, and only users with the `Passenger` role can file complaints.

### 🛣️ Route and Stop Management

The system models routes and reusable stops. The `ROUTE_STOP` junction table resolves the many-to-many relationship between routes and stops and records the sequence of each stop using `stop_order`.

### 💰 Temporal Fare Management

The `FARE` table stores approved fare amounts between two stops on a route. Each fare has an effective date range:

- `effective_from`: date the fare becomes valid
- `effective_to`: date the fare expires
- `NULL effective_to`: fare is currently open-ended

Historical fare records remain protected by foreign-key restrictions.

### 📝 Complaint Filing and Tracking

Passengers can report a fare dispute using the bus, fare, journey date/time, amount paid, and description. Optional evidence can be stored in `COMPLAINT_PHOTO`.

A trigger generates a UUID-derived tracking number in this format:

`FD-YYMMDD-XXXXXX`

The tracking number is protected by a unique constraint.

### 📋 Review History

`COMPLAINT_REVIEW` stores every administrator decision instead of overwriting previous decisions. Supported decisions are:

- Under Review
- Resolved
- Rejected

A trigger automatically updates the parent complaint's current status after each review.

### 📊 Analytics

The database includes views for:

- Complaint details and calculated fare differences
- Complaint totals and positive overcharge totals by operator
- Complaint totals and average overcharge by route
- Currently active fare records
- Complaint review audit history

The analytics views use `GREATEST(amount_paid - approved_fare, 0)`, so complaints with no overcharge do not reduce the total positive overcharge.

---

## 🗄️ Database Architecture

The database contains **10 tables**, **4 views**, indexes, and triggers.

```text
BUS_OPERATOR  1 ──── N  BUS  1 ──── N  COMPLAINT
                                       │
ROUTE         1 ──── N  FARE  1 ──── N ├── COMPLAINT_PHOTO
   │              │                     │
   │              └────────────────────┘
   │
   └──── N  ROUTE_STOP  N ──── 1  STOP

USER (Passenger) 1 ──── N COMPLAINT
USER (Admin)     1 ──── N FARE
USER (Admin)     1 ──── N COMPLAINT_REVIEW
COMPLAINT        1 ──── N COMPLAINT_REVIEW
```

### 📚 Table Breakdown

| Table | Primary Key | Purpose |
|---|---|---|
| `USER` | `user_id` | Stores passengers and administrators. |
| `BUS_OPERATOR` | `operator_id` | Stores transport operators and license information. |
| `BUS` | `bus_id` | Stores individual buses and their operators. |
| `ROUTE` | `route_id` | Stores route names, origins, and destinations. |
| `STOP` | `stop_id` | Stores reusable bus stops. |
| `ROUTE_STOP` | `route_id, stop_id` | Resolves route-stop M:N mapping and stores stop order. |
| `FARE` | `fare_id` | Stores approved fares and validity dates. |
| `COMPLAINT` | `complaint_id` | Stores passenger fare dispute reports. |
| `COMPLAINT_PHOTO` | `photo_id` | Stores optional evidence file paths. |
| `COMPLAINT_REVIEW` | `review_id` | Stores administrator decisions and remarks. |

---

## 🔐 Constraints, Triggers, and Referential Integrity

The database enforces:

- Unique email addresses, operator license numbers, bus numbers, route names, and complaint tracking numbers.
- `approved_fare >= 0`.
- `amount_paid > 0`.
- `stop_order > 0`.
- Fare validity dates where `effective_to` cannot be earlier than `effective_from`.
- Different boarding and destination stops.
- Both fare stops must belong to the selected route.
- Complaint journey dates must fall within the linked fare's validity period.
- Only Admin users can manage fares or create reviews.
- Only Passenger users can file complaints.
- Complaint status synchronization after review insertion.
- `ON DELETE RESTRICT` for historical fare, bus, complaint, and user relationships.
- `ON DELETE CASCADE` for route-stop, complaint-photo, and complaint-review dependent records.
- `ON UPDATE CASCADE` for foreign-key relationships.

The fare difference is derived dynamically:

`fare_difference = amount_paid - approved_fare`

It is calculated in `v_complaint_details` instead of being stored redundantly.

### 🧮 MySQL Compatibility

The rule that boarding and destination stops must differ is enforced by `trg_fare_bi` and `trg_fare_bu`. It is implemented with triggers because MySQL rejects a table-level CHECK constraint that references foreign-key columns with cascading actions (Error 3823).

The script contains **10 tables, 4 views, 6 indexes, and 7 triggers**.

---

## 🖥️ Requirements

- XAMPP
- MySQL 8.0.16+ or MariaDB 10.4+
- phpMyAdmin
- A web browser
- Apache is required only if a PHP website is also being used

---

## 🚀 XAMPP Installation

### Step 1: Install XAMPP

1. Download XAMPP from [apachefriends.org](https://www.apachefriends.org/download.html).
2. Run the installer.
3. Install at least **Apache**, **MySQL**, and **phpMyAdmin**.
4. The default installation directory is recommended: `C:\xampp`.

### Step 2: Start the Services

1. Open the **XAMPP Control Panel**.
2. Start **MySQL**.
3. Start **Apache** if the project includes a PHP frontend.
4. Open phpMyAdmin at [http://localhost/phpmyadmin](http://localhost/phpmyadmin).

### Port Troubleshooting

If MySQL cannot start because port 3306 is already in use:

1. Open **Config → my.ini** in the XAMPP Control Panel.
2. Change the MySQL port from `3306` to `3307`.
3. Use port `3307` in application connection settings and MySQL commands.

---

## 📥 Import the Database

### Method 1: phpMyAdmin

1. Open [http://localhost/phpmyadmin](http://localhost/phpmyadmin).
2. Click the **Import** tab.
3. Click **Choose File**.
4. Select `fare_dispute_redressal.sql`.
5. Keep the format as **SQL**.
6. Click **Import** or **Go**.
7. Select `fare_dispute_db` from the left sidebar.

The SQL script creates the database, tables, relationships, indexes, triggers, views, sample data, and test queries.

> ⚠️ **Important:** The script begins with `DROP DATABASE IF EXISTS fare_dispute_db`. Importing it deletes and recreates that database. Back up existing data before importing.

### Method 2: MySQL Command Line

From the folder containing the SQL file:

```bash
mysql -u root -p < fare_dispute_redressal.sql
```

For a default Windows XAMPP installation:

```powershell
cd C:\xampp\mysql\bin
.\mysql.exe -u root -p < "D:\#Study\CSE311\fare-dispute-redressal-system\fare_dispute_redressal.sql"
```

If MySQL is configured on port 3307:

```powershell
.\mysql.exe -P 3307 -u root -p < "D:\#Study\CSE311\fare-dispute-redressal-system\fare_dispute_redressal.sql"
```

If the default XAMPP root account has no password, press **Enter** when prompted.

---

## ✅ Verify the Import

Run the following in phpMyAdmin's **SQL** tab:

```sql
USE fare_dispute_db;

SHOW TABLES;

SHOW FULL TABLES
WHERE Table_type = 'VIEW';

SELECT COUNT(*) AS total_complaints
FROM COMPLAINT;

SELECT *
FROM v_current_fares;

SELECT tracking_number,
       passenger_name,
       route_name,
       bus_number,
       approved_fare,
       amount_paid,
       fare_difference,
       status
FROM v_complaint_details;
```

Expected sample data includes:

- 10 tables
- 4 views
- 4 complaints
- 5 current fares
- 3 bus operators
- 4 buses
- 2 routes
- 7 stops
- 2 Admin users
- 3 Passenger users

### 📋 Expected Object Counts

| Object | Expected Count |
|---|---:|
| Base tables | 10 |
| Views | 4 |
| Indexes created by the script | 6 |
| Triggers | 7 |
| Users | 5 |
| Bus operators | 3 |
| Buses | 4 |
| Routes | 2 |
| Stops | 7 |
| Route-stop rows | 10 |
| Fares | 5 |
| Complaints | 4 |
| Complaint photos | 3 |
| Complaint reviews | 3 |

---

## 🔍 Verification Queries and Demo Walkthrough

### 1. Complaint Tracking and Fare Difference

```sql
SELECT tracking_number,
       passenger_name,
       route_name,
       bus_number,
       approved_fare,
       amount_paid,
       fare_difference,
       status
FROM v_complaint_details;
```

The tracking value is generated from a UUID substring and follows the custom format `FD-YYMMDD-XXXXXX`; it is not a full UUID.

### 2. Operator Complaint Analytics

```sql
SELECT operator_name,
       operator_status,
       total_complaints,
       total_overcharge AS total_overcharge_bdt
FROM v_operator_complaints
ORDER BY total_complaints DESC, total_overcharge DESC;
```

### 3. Route Dispute Analytics

```sql
SELECT route_name,
       total_complaints,
       ROUND(avg_overcharge, 2) AS avg_overcharge_bdt
FROM v_route_disputes
ORDER BY total_complaints DESC, avg_overcharge DESC;
```

### 4. Current Fare Lookup

```sql
SELECT *
FROM v_current_fares
WHERE route_name = 'Mirpur-10 to Motijheel';
```

### 5. Complaint Review Audit Trail

```sql
SELECT c.tracking_number,
       u.full_name AS admin_name,
       cr.decision,
       cr.remarks,
       cr.reviewed_at
FROM COMPLAINT_REVIEW cr
JOIN COMPLAINT c ON c.complaint_id = cr.complaint_id
JOIN `USER` u ON u.user_id = cr.admin_id
ORDER BY cr.reviewed_at ASC;
```

---

## 🛡️ Constraint Testing

Run these statements individually after importing the database. They are expected to fail and demonstrate the trigger rules.

```sql
USE fare_dispute_db;

-- Passenger attempting to create a review
INSERT INTO COMPLAINT_REVIEW
    (complaint_id, admin_id, decision, remarks)
VALUES
    (1, 3, 'Resolved', 'Unauthorized passenger review');

-- Boarding and destination stops are identical
INSERT INTO FARE
    (route_id, from_stop_id, to_stop_id, approved_fare, effective_from, managed_by)
VALUES
    (1, 1, 1, 15.00, '2026-01-01', 1);

-- Journey date is outside the fare validity period
INSERT INTO COMPLAINT
    (passenger_id, bus_id, fare_id, journey_date, amount_paid, description)
VALUES
    (3, 1, 1, '2025-06-15', 50.00, 'Backdated journey complaint');
```

Do not re-import the entire SQL file to test one statement because the script recreates the database.

---

## 📦 Sample Data

The SQL script includes:

- 2 Admin users and 3 Passenger users
- 3 bus operators and 4 buses
- 2 routes and 7 stops
- Route-stop sequences
- 5 current fare records
- 4 complaints
- Complaint photo paths
- Administrator review history

The sample `password_hash` values are placeholders for demonstration and are not production login passwords.

---

## 📂 Repository Files

```text
fare-dispute-redressal-system/
├── README.md
├── README.txt
└── fare_dispute_redressal.sql
```

---

## 📜 Academic Integrity

This project was developed by Team 06 for **CSE311L: Database Systems Lab** at **North South University**. It is intended for academic evaluation, demonstration, and educational use.
