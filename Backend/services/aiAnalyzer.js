const { GoogleGenerativeAI } = require("@google/generative-ai");
const fs = require('fs');
const path = require('path');

class CivicIssueAnalyzer {
    constructor(apiKey) {
        if (!apiKey) {
            throw new Error("Google API key not provided.");
        }
        this.genAI = new GoogleGenerativeAI(apiKey);
        this.model = this.genAI.getGenerativeModel({ model: "gemini-flash-latest" }); // Using latest Flash model (2026 compatible)

        try {
            const mappingPath = path.join(__dirname, '../mapping.json');
            const rawData = fs.readFileSync(mappingPath);
            this.mappingData = JSON.parse(rawData);
            console.log('Mapping data loaded successfully.');
        } catch (error) {
            console.error("Error loading mapping.json:", error);
            this.mappingData = {};
        }

        // Set active 5 core categories as the only ALLOWED choices for AI
        this.VALID_ISSUE_TYPES = [
            "pothole",
            "streetlight_not_working",
            "garbage_overflow",
            "water_leakage",
            "sewage_overflow"
        ];
        console.log('Civic AI restricted to core types:', this.VALID_ISSUE_TYPES);

        this.VALID_SEVERITY = ['high', 'medium', 'low', 'none'];
    }

    _createPrompt() {
        return `
    You are an AI for a civic monitoring app. Analyze the image and classify it into EXACTLY ONE of these 5 categories:
    - 'pothole': For any road damage, cracks, or potholes.
    - 'streetlight_not_working': For any lighting or electrical pole issues.
    - 'garbage_overflow': For any trash, dumping, or overflowing dustbins.
    - 'water_leakage': For any clear water leaks or broken pipes.
    - 'sewage_overflow': For any drainage, sewage, or dirty water overflow.

    Pick the closest fit from: ${JSON.stringify(this.VALID_ISSUE_TYPES)}.
    
    Respond ONLY with a JSON object:
    1. 'issue_type': The category string.
    2. 'severity': One of ['high', 'medium', 'low', 'none'].
    3. 'confidence': Float 0.0 to 1.0.
    4. 'description': 1–2 sentences describing the issue.
    `;
    }

    async analyzeImage(imageInput, mimeType = 'image/jpeg') {
        console.log(`Analyzing image input...`);

        // Helper to prepare GenerativePart
        function toGenerativePart(data, mimeType) {
            return {
                inlineData: {
                    data: data,
                    mimeType
                },
            };
        }

        let imagePart;

        if (imageInput.startsWith('data:image')) {
            // Handle Base64 String
            console.log("Input is Base64 string.");
            const matches = imageInput.match(/^data:(.+);base64,(.+)$/);
            if (!matches || matches.length !== 3) {
                console.error("Invalid Base64 string format");
                throw new Error("Invalid Base64 string");
            }
            const determinedMimeType = matches[1];
            const base64Data = matches[2];
            imagePart = toGenerativePart(base64Data, determinedMimeType);
        } else {
            // Handle File Path
            console.log(`Input is file path: ${imageInput}`);
            if (!fs.existsSync(imageInput)) {
                console.error("File not found:", imageInput);
                throw new Error("Image file not found for analysis");
            }
            const fileData = fs.readFileSync(imageInput).toString("base64");
            imagePart = toGenerativePart(fileData, mimeType);
        }

        try {
            const prompt = this._createPrompt();
            // imagePart is already prepared above

            const result = await Promise.race([

                this.model.generateContent([prompt, imagePart]),
                new Promise((_, reject) =>
                    setTimeout(() => reject(new Error('Gemini API request timeout after 90s')), 90000)
                )
            ]);
            const response = await result.response;
            const text = response.text();

            console.log("Gemini Raw Response:", text);

            let aiResult;
            try {
                const cleanText = text.replace(/```json/g, "").replace(/```/g, "").trim();
                aiResult = JSON.parse(cleanText);
            } catch (parseError) {
                console.error("Failed to parse AI response:", text);
                throw new Error("Invalid JSON response from AI");
            }

            // Encode department info
            const category = aiResult.issue_type;
            const mappingDetails = this.mappingData[category] || {};

            const finalResult = {
                ...aiResult,
                department: mappingDetails.department || "Unknown Department",
                responsible: mappingDetails.responsible || "Unknown Authority"
            };

            return finalResult;

        } catch (error) {
            console.error("AI Analysis Error:", error);

            // Provide more specific error messages
            if (error.message && error.message.includes('fetch failed')) {
                console.error("Network connectivity issue: Cannot reach Google Gemini API");
                console.error("Possible causes: Firewall, proxy, VPN, or network restrictions");
                console.error("Check your internet connection and firewall settings");
            } else if (error.message && error.message.includes('timeout')) {
                console.error("Gemini API request timed out after 90 seconds");
            }

            throw error;
        }
    }
}

module.exports = CivicIssueAnalyzer;
