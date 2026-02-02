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
            this.VALID_ISSUE_TYPES = Object.keys(this.mappingData);
            console.log('Mapping data loaded successfully. Issue types:', this.VALID_ISSUE_TYPES.length);
        } catch (error) {
            console.error("Error loading mapping.json:", error);
            this.mappingData = {};
            this.VALID_ISSUE_TYPES = [];
        }

        this.VALID_SEVERITY = ['high', 'medium', 'low', 'none'];
    }

    _createPrompt() {
        return `
    You are an AI for a civic monitoring app in Tamil Nadu, India. Analyze the image and classify the primary civic issue.
    Respond ONLY with a JSON object with four keys:
    1. 'issue_type': Pick ONE from this list: ${JSON.stringify(this.VALID_ISSUE_TYPES)}.
    2. 'severity': One of ['high', 'medium', 'low', 'none'].
    3. 'confidence': Float 0.0 to 1.0.
    4. 'description': 1–2 natural sentences describing the issue.

    Do not invent any other categories.
    Respond only with the raw JSON.
    `;
    }

    async analyzeImage(imagePath, mimeType) {
        console.log(`Analyzing image: ${imagePath}`);

        // Convert image file to GenerativePart
        function fileToGenerativePart(path, mimeType) {
            return {
                inlineData: {
                    data: Buffer.from(fs.readFileSync(path)).toString("base64"),
                    mimeType
                },
            };
        }

        try {
            const prompt = this._createPrompt();
            const imagePart = fileToGenerativePart(imagePath, mimeType);

            const result = await this.model.generateContent([prompt, imagePart]);
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
            throw error;
        }
    }
}

module.exports = CivicIssueAnalyzer;
