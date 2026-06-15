/**
 * @file chatController.js
 * @description Controller for the AI Chatbot logic using Google Gemini.
 */
const { GoogleGenerativeAI } = require("@google/generative-ai");

// Initialize Gemini
const GEN_AI_KEY = process.env.GEMINI_API_KEY;

if (!GEN_AI_KEY) {
    console.error("CRITICAL: GEMINI_API_KEY is missing in .env file");
}

const genAI = new GoogleGenerativeAI(GEN_AI_KEY || 'dummy-key');

const SYSTEM_INSTRUCTION = `
You are 'Vidhya', the Official AI Assistant for the Tamil Nadu Civic App. 
Your role is to assist citizens with government services, reporting issues, and tracking complaints data.

**HOW TO REPORT AN ISSUE (Guide Users with these steps):**
1. Tap the **'+' or 'Report'** button on your Home Dashboard.
2. **Camera/Gallery**: Upload a clear photo of the problem (pothole, garbage, etc.).
3. **AI Analysis**: Our system automatically detects the category and severity from your photo.
4. **Details**: Add a brief description and set the severity.
5. **Submit**: You'll receive an instant notification and a Tracking ID.

**PROJECT KNOWLEDGE BASE:**
- **Community Verification**: Briefly explain that neighbors can click 'Verify' on nearby reports. If 3+ people verify, the issue is escalated to 'VERIFIED' status.
- **Impact & Points**: Users earn 10 points for reporting and 5 points for verifying. Check the **Leaderboard** to see your ranking!
- **Real-Time Tracking**: All reports are monitored 24/7. Users get notifications for status changes (Pending -> Assigned -> In Progress -> Resolved).
- **Districts**: We currently support all major districts of Tamil Nadu including Erode, Chennai, Pudukottai, and Kanyakumari.

**PERSONA GUIDELINES:**
1. **Professional & Empathetic**: Speak like a helpful government official.
2. **Security & Privacy**: Never ask for passwords, PINs, or sensitive Aadhaar details.
3. **Multilingual**: Understand Tamil and English. Reply in the language the user speaks.
4. **Action-Oriented**: Always try to guide the user to a specific app feature using the JSON actions below.

**AVAILABLE APP ACTIONS (JSON Strings):**
- Reporting an Issue -> {"action": "NAVIGATE_REPORT"}
- Viewing Map / Nearby Issues -> {"action": "NAVIGATE_MAP"}
- Checking Status / My Reports -> {"action": "NAVIGATE_MY_REPORTS"}
- Community Feed / News -> {"action": "NAVIGATE_FEED"}
- Emergency Support -> {"action": "CALL_EMERGENCY"}

**RESPONSE FORMAT:**
Return a JSON object:
{
  "text": "Your helpful response with step-by-step guidance. Use **bold** for emphasis.",
  "action": "ACTION_CODE_OR_NULL",
  "language": "en" | "ta"
}
`;

/**
 * Processes a user message using Google's Gemini AI.
 */
exports.handleChat = async (req, res) => {
    try {
        const { message, history } = req.body;
        const db = req.app.locals.db;

        if (!message) {
            return res.status(400).json({ success: false, message: "Message is required" });
        }

        // 1. Context Enhancement: Check if user mentioned a Report ID?
        let internalContext = "";
        
        const idMatch = message.match(/\b([a-zA-Z0-9]{20})\b/) || message.match(/REP_(\w+)/);

        if (idMatch) {
            const reportId = idMatch[0]; 
            try {
                const doc = await db.collection('reports').doc(reportId).get();
                if (doc.exists) {
                    const data = doc.data();
                    internalContext = `\n[SYSTEM DATA: Report ${reportId} found. Status: ${data.status.toUpperCase()}, Category: ${data.category}, Severity: ${data.severity}, Location: ${data.district}. Inform the user details based on this.]`;
                } else {
                    internalContext = `\n[SYSTEM DATA: User searched for Report ${reportId} but it was NOT found in database. Inform them to check the ID.]`;
                }
            } catch (err) {
                console.log("Context fetch error", err);
            }
        }

        const model = genAI.getGenerativeModel({
            model: "gemini-flash-latest",
            systemInstruction: SYSTEM_INSTRUCTION + internalContext
        });

        // Transform history to ensuring strict 'parts' structure
        const formattedHistory = (history || []).map(msg => ({
            role: msg.role === 'user' ? 'user' : 'model',
            parts: Array.isArray(msg.parts) ? msg.parts : [{ text: typeof msg.parts === 'string' ? msg.parts : (msg.text || '') }]
        }));

        const chat = model.startChat({
            history: formattedHistory,
            generationConfig: {
                maxOutputTokens: 500,
                temperature: 0.7,
            },
        });

        const result = await chat.sendMessage(message);
        const response = await result.response;
        const text = response.text();

        // Attempt to parse if the model outputted JSON string
        let cleanText = text.replace(/\`\`\`json/g, '').replace(/\`\`\`/g, '').trim();
        let parsedResponse;

        try {
            parsedResponse = JSON.parse(cleanText);
        } catch (e) {
            console.log("Model didn't output strict JSON, using text fallback");
            parsedResponse = {
                text: cleanText,
                action: null,
                language: 'en'
            };
        }

        res.json({ success: true, ...parsedResponse });

    } catch (error) {
        console.error("Chat Error:", error);
        res.status(500).json({ success: false, message: "AI Service Unavailable", error: error.message });
    }
};
