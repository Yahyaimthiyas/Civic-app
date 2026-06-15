# Civic-App: Architecture and Flow Diagrams

These diagrams use Mermaid to visualize the architecture and data flows of your project. They are extremely useful for system design rounds in interviews. You can draw these on a whiteboard or explain them conceptually.

## 1. High-Level System Architecture

This diagram shows the core components of the system and how they interact.

```mermaid
graph TD
    %% Mobile Application %%
    subgraph "Frontend (Flutter App)"
        UI[User Interface]
        Riverpod[State Management - Riverpod]
        Map[Location Services - Geolocator/Map]
        Cam[Hardware Services - Camera/Mic]
    end

    %% Backend Server %%
    subgraph "Backend (Node.js & Express)"
        API[REST API Router]
        Auth[Aadhaar Auth & OTP Controller]
        Rep[Reporting & Feed Caching Service]
        Chat[AI Chatbot Controller]
    end

    %% External Services %%
    subgraph "External Integrations"
        Gemini[Google Generative AI - Gemini Flash]
        Firestore[(Firebase Firestore - NoSQL)]
    end

    UI --> Riverpod
    Riverpod -- HTTP Requests --> API
    Map -.-> Riverpod
    Cam -.-> Riverpod

    API --> Auth
    API --> Rep
    API --> Chat

    Auth -- Validate & Store User --> Firestore
    Rep -- Send Image for Analysis --> Gemini
    Chat -- Process Natural Language --> Gemini
    Rep -- Save Reports & Upvotes --> Firestore
```

---

## 2. Issue Reporting & AI Analysis Flow

This sequence diagram illustrates exactly what happens from the moment a user clicks "Submit" to when the report is saved.

```mermaid
sequenceDiagram
    participant Citizen
    participant App as Flutter App
    participant Node as Node.js Backend
    participant Gemini as Gemini AI
    participant DB as Firestore DB

    Citizen->>App: Take Photo & Enter Details
    App->>App: Fetch GPS Coordinates
    App->>Node: POST /report/submit (Base64 Image, Location)
    Node->>Gemini: analyzeImage(Base64)
    Note over Node,Gemini: AI Interception Phase
    Gemini-->>Node: Returns auto-categorized data (e.g., Pothole, High Severity)
    Node->>Node: Generate Unique Tracking ID (e.g., TN-2026-XYZ)
    Node->>DB: Save Report (Status: Pending)
    DB-->>Node: Document ID Confirmation
    Node->>DB: Trigger Push Notification Entry
    Node-->>App: HTTP 200 Success & Tracking ID
    App-->>Citizen: Display Success Screen
```

---

## 3. Aadhaar Authentication Flow (Simulated)

This sequence diagram shows the logic used to verify trust and limit access to valid, 18+ Tamil Nadu residents.

```mermaid
sequenceDiagram
    participant Citizen
    participant App as Flutter App
    participant Node as Node.js Backend
    participant DB as Firestore Registry
    participant Mem as Server Memory Cache

    Citizen->>App: Enter 12-Digit Aadhaar
    App->>Node: POST /aadhaar/send-otp
    Node->>DB: Query aadhaarRegistry
    DB-->>Node: Return User Data
    Note over Node,DB: Validation: Age >= 18 & State == 'Tamil Nadu'
    Node->>Node: Generate 6-digit OTP
    Node->>Mem: Store OTP with 5-minute expiry
    Node-->>App: Success (OTP Logged to console in Dev)
    Citizen->>App: Input OTP
    App->>Node: POST /aadhaar/verify-otp
    Node->>Mem: Check OTP match & attempts
    Mem-->>Node: Validated
    Node->>Mem: Clear OTP from Memory
    Node-->>App: Auth Success + User Session Data
```

---

## 4. Community Verification (Crowdsourcing) Flow

How reports escalate statuses automatically without admin intervention.

```mermaid
sequenceDiagram
    participant Citizen B
    participant App as Flutter App
    participant Node as Node.js Backend
    participant DB as Firestore DB

    Citizen B->>App: View Public Map / Feed
    App->>Node: GET /report/feed
    Node-->>App: Return nearby reports (from in-memory cache)
    Citizen B->>App: Click "Verify" on a neighbor's report
    App->>Node: POST /verify/:reportId
    Node->>DB: Add User ID to 'verifiedBy' array
    Node->>Node: Check if verificationCount >= 3
    alt Threshold Reached
        Node->>DB: Update Status: PENDING -> VERIFIED
        Node->>DB: Append to Report History Log
    end
    Node-->>App: Verification Recorded
    App-->>Citizen B: Update UI & Award Impact Points
```
