# SRU New Portal API Technical Report

## Overview
This document summarizes the findings regarding the new SRU portal (`https://www.sruniv.com/student/timetable`) and its API.

## Discovered Information
Currently, the new portal is protected by an authentication wall and potentially CAPTCHA/OTP systems. Because of strict rules against guessing endpoints, bypassing authentication, or scraping protected data, we have not fully mapped the backend API of the new SRU portal.

### Known Constraints:
- **Authentication**: Required to access student/faculty timetables.
- **Official API**: Not officially published. The integration requires careful handling of session cookies or tokens returned by SRU's login flow.
- **Data Privacy**: No credentials, OTPs, cookies, or session IDs are logged or stored persistently in plaintext.

## What Remains Blocked
Because we cannot bypass authentication to inspect network requests directly, the exact HTTP methods, request parameters, response schemas, and token architectures of the new portal are blocked.
- Student timetable endpoint
- Faculty timetable endpoint
- Profile endpoint
- OTP flow behavior

## Action Plan
Instead of hardcoding a fake API, we are implementing a robust abstraction layer:
1. **SruAuthService**: An abstract interface for handling login, OTP, and session management.
2. **SruStudentSource & SruFacultySource**: Interfaces to abstract the timetable retrieval.
3. **Admin Import**: Kept as a reliable fallback if the new SRU source remains completely inaccessible programmatically.

This ensures the Flutter app remains safe, compliant, and ready to plug in the exact SRU API implementation once the endpoints are officially provided or manually documented.
