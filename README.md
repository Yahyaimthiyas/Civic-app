# Civic Connect - Tamil Nadu Civic Reporting Platform

Civic Connect is a secure, interactive full-stack platform that empowers citizens of Tamil Nadu to report, track, and verify public infrastructure issues. Integrated with Aadhaar authentication for accountability, Google Gemini AI for automated issue classification, and a live OpenStreetMap dashboard, it automates civic grievance workflows for citizens and municipal administrators.

---

## 🚀 Key Features

*   **🔒 Secure Aadhaar Authentication**: OTP-based login verified against a simulated Aadhaar Registry to prevent spoofing and ensure citizen accountability.
*   **📸 Verified Reporting with Watermarking**: Photo capture utilizes client-side pixel manipulation to stamp GPS coordinates, physical address, and timestamp directly onto the image bytes.
*   **🧠 AI-Powered Analysis**: The backend processes images using Google's **Gemini-Flash** model to instantly categorize issues (e.g., pothole, streetlight) and determine urgency levels.
*   **👥 Crowd-Sourced Verification**: Local citizens can view nearby complaints on an interactive map and click "Verify". Once a threshold of 3 verifications is reached, the issue escalates to `VERIFIED` status.
*   **👷 Live SLA Monitoring & Worker Assignment**: Tracks reports through standard lifecycle updates: `PENDING` ➔ `VERIFIED` ➔ `IN_PROGRESS` ➔ `RESOLVED`.
*   **💬 "Vidhya" Chatbot assistant**: A generative AI chatbot inside the app that guides citizens, retrieves complaint details, and triggers page navigation in real-time.
*   **🎮 Gamification Leaderboard**: Citizens earn points for reporting issues (+10 pts) and verifying neighborhood reports (+5 pts).

---

## 🛠️ Technology Stack

### Mobile Frontend
*   **Language & SDK**: Dart / Flutter
*   **State Management**: Riverpod
*   **Maps & Geolocation**: `flutter_map` (OpenStreetMap provider), `latlong2`, `geolocator`, `geocoding`
*   **Image Handling**: `image` (manual canvas pixel stamping), `image_picker`
*   **Storage**: `shared_preferences` (offline-first caching of feed and dashboard details)

### Backend Services
*   **Runtime & Framework**: Node.js / Express.js
*   **Database Ecosytem**: Firebase Admin SDK (Firestore NoSQL DB)
*   **Generative AI**: `@google/generative-ai` (Gemini SDK)
*   **File Uploads**: `multer`

---

## 📂 Directory Structure

```text
├── Backend/                    # Node.js/Express Backend API
│   ├── controllers/            # Route business logic (auth, reports, chat)
│   ├── routes/                 # API Endpoint routes
│   ├── services/               # AI analyzers and database monitors
│   ├── utils/                  # Cryptographic generators, SLA and location helpers
│   ├── mapping.json            # Category-to-Department routing configuration
│   └── server.js               # API Server Entry Point
│
├── flutterapp/                 # Flutter Mobile Client
│   ├── lib/
│   │   ├── core/               # Global configurations, themes, global widgets
│   │   │   ├── network/        # API Constants & network URLs
│   │   │   ├── theme/          # App design system & color definitions
│   │   │   └── widgets/        # Shared components (improved cards, sharesheets)
│   │   ├── features/           # Modularized feature folders
│   │   │   ├── auth/           # Aadhaar registry inputs, pin setups, OTPs
│   │   │   ├── chatbot/        # "Vidhya" AI assistant interfaces
│   │   │   ├── complaints/     # Map views, reporting tools, details page
│   │   │   ├── home/           # Dashboard views and feeds
│   │   │   └── profile/        # User stats, security options, logout
│   │   └── main.dart           # App bootstrapper
│   └── pubspec.yaml            # Dart package configuration
```

---

## ⚙️ Setup & Installation

### Prerequisite Setup
1.  **Firebase Project**: Create a Firebase project and generate a Service Account Private Key. Save it as `Backend/serviceAccountKey.json`.
2.  **Google AI Studio**: Obtain a Gemini API Key from Google AI Studio.

### Backend Setup
1.  Navigate to the Backend directory:
    ```bash
    cd Backend
    ```
2.  Install dependencies:
    ```bash
    npm install
    ```
3.  Configure the environment variables in a `.env` file:
    ```env
    PORT=4000
    GEMINI_API_KEY=your_gemini_api_key
    ```
4.  Start the Server:
    ```bash
    npm start
    ```

### Frontend Setup
1.  Navigate to the Flutter directory:
    ```bash
    cd flutterapp
    ```
2.  Configure API endpoint base URL in `lib/core/network/api_constants.dart`:
    ```dart
    // Replace with your machine's IP address if running on physical device
    static const String baseUrl = 'http://<YOUR_DEV_MACHINE_IP>:4000';
    ```
3.  Add your `google-services.json` file inside the `android/app/` folder.
4.  Fetch flutter packages:
    ```bash
    flutter pub get
    ```
5.  Launch the application:
    ```bash
    flutter run
    ```
