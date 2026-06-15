# Civic-App: End-to-End System Flow

This flowchart represents the entire lifecycle of the Civic-App, simplified for better visibility and readability.

```mermaid
flowchart TD
    %% Authentication
    Start([User Opens App]) --> AuthCheck{Is Logged In?}
    AuthCheck -- No --> EnterAadhaar[Enter 12-Digit Aadhaar]
    EnterAadhaar --> BackendValidate[Backend: Validate Age 18+ & Tamil Nadu State]
    BackendValidate -- Valid --> SendOTP[Backend: Generate In-Memory OTP]
    SendOTP --> EnterOTP[User: Enters OTP]
    EnterOTP --> VerifyOTP[Backend: Verify OTP & Create Session]
    
    AuthCheck -- Yes --> Dashboard
    VerifyOTP --> Dashboard([User Dashboard])

    %% Main Actions
    Dashboard --> Action{Choose Action}

    %% Branch 1: Chatbot
    Action -->|Ask for Help| Chatbot[Open Chatbot 'Vidhya']
    Chatbot --> GeminiNLP[Gemini AI: Process Natural Language]
    GeminiNLP --> ChatResult{Returns JSON Action?}
    ChatResult -- Yes --> Action
    ChatResult -- No --> ShowReply[Display AI Text Reply]

    %% Branch 2: Reporting & AI
    Action -->|Report Issue| Camera[Capture Photo & GPS Location]
    Camera --> Submit[POST /report/submit]
    Submit --> GeminiAnalyze[Gemini AI: Analyze Image]
    
    GeminiAnalyze --> AI_Success{AI Detection Success?}
    AI_Success -- Yes --> AutoCat[Auto-Categorize & Set Severity]
    AI_Success -- No --> Fallback[Fallback to User Category]
    
    AutoCat --> SaveDB[(Firestore: Save Report as PENDING)]
    Fallback --> SaveDB
    SaveDB --> Notify[Push Notification to User]

    %% Branch 3: Community Verification
    Action -->|View Feed/Map| ViewMap[Fetch Cached Feed & View Map]
    SaveDB -.-> ViewMap
    ViewMap --> Neighbor[Neighbor views pending issue]
    Neighbor --> Verify[Click 'Verify' Issue]
    Verify --> IncrementDB[(Firestore: Increment Verification Count)]
    
    IncrementDB --> Threshold{Count >= 3?}
    Threshold -- No --> RemainPending[Status: PENDING]
    Threshold -- Yes --> Escalate[(Firestore: Auto-Escalate to VERIFIED)]

    %% Resolution
    Escalate --> Assign[Admin Assigns Issue]
    Assign --> Resolve[(Update Status to RESOLVED)]
    Resolve --> NotifyResolved[Notify Original Reporter]
```

### Key Stages Explained
1. **Authentication (Top):** Validates the user's Aadhaar details (Age/State) before sending an OTP.
2. **AI Chatbot (Left):** "Vidhya" processes text and either replies normally or triggers an app navigation action.
3. **AI Reporting (Center):** The core feature where Gemini automatically categorizes the civic issue based on the uploaded photo.
4. **Community Verification (Right):** The crowdsourcing engine where 3 verifications automatically escalate the report to the authorities.
