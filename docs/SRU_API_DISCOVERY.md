# SRU API Discovery

This document records the exact network requests and endpoints discovered from the SRU Timetable portal (`https://timetable.sruniv.com`).

## Authentication Flow

### 1. Initial Login Page (GET)
- **Method:** GET
- **URL:** `https://timetable.sruniv.com/login`
- **Purpose:** Fetches the HTML form to extract the CSRF `_token` and initializes the PHP session cookie (`PHPSESSID`).

### 2. Submit Credentials (POST)
- **Method:** POST
- **URL:** `https://timetable.sruniv.com`
- **Content-Type:** `application/x-www-form-urlencoded`
- **Request Body:**
  - `_token`: CSRF token extracted from the login page
  - `login_identifier`: Student Enrollment Number / Faculty ID / Email
  - `password`: User password
- **Response:** 302 Redirect to OTP verification page or dashboard. Sets authenticated session cookies.

### 3. Verify OTP (POST)
- **Method:** POST
- **URL:** `https://timetable.sruniv.com/verify-otp` (Assumed based on previous SRU app behavior)
- **Content-Type:** `application/x-www-form-urlencoded`
- **Request Body:**
  - `_token`: CSRF token
  - `otp`: The 6-digit OTP code received via SMS/Email
- **Response:** 302 Redirect to dashboard upon successful verification.

## Data Endpoints

*Note: The actual authenticated endpoints below have been approximated based on expected portal structure since active authenticated credentials were not provided during this session. A manual Chrome DevTools HAR trace by the user is required to confirm exact student/faculty URLs.*

### Student Profile (Expected)
- **Method:** GET
- **URL:** `https://timetable.sruniv.com/student/profile` (or equivalent dashboard URL)
- **Response:** HTML document containing student details (Name, Enrollment No, Branch, etc.). 

### Student Timetable (Expected)
- **Method:** GET
- **URL:** `https://timetable.sruniv.com/student/timetable` (or equivalent)
- **Response:** HTML or JSON containing the weekly class schedule.

### Faculty Profile (Expected)
- **Method:** GET
- **URL:** `https://timetable.sruniv.com/faculty/profile`

### Faculty Timetable (Expected)
- **Method:** GET
- **URL:** `https://timetable.sruniv.com/faculty/timetable`

---
**CRITICAL:** Do NOT document actual passwords, OTPs, or active session cookies in this file or any logs.
