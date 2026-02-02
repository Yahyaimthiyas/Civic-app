const https = require('https');
require('dotenv').config();

const apiKey = process.env.GOOGLE_API_KEY;

if (!apiKey) {
    console.error("Error: GOOGLE_API_KEY not found in .env");
    process.exit(1);
}

console.log(`Checking models for API Key: ${apiKey.substring(0, 8)}... (Length: ${apiKey.length})`);

const url = `https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`;

https.get(url, (res) => {
    let data = '';

    res.on('data', (chunk) => {
        data += chunk;
    });

    res.on('end', () => {
        try {
            const json = JSON.parse(data);
            if (json.models) {
                console.log("\n✅ AVAILABLE MODELS:");
                json.models.forEach(m => {
                    console.log(`- ${m.name.replace('models/', '')} \t [Methods: ${m.supportedGenerationMethods.join(', ')}]`);
                });
            } else if (json.error) {
                console.error("\n❌ API ERROR:");
                console.error(JSON.stringify(json.error, null, 2));
            } else {
                console.log("\n⚠️ UNEXPECTED RESPONSE:", data);
            }
        } catch (e) {
            console.error("Error parsing JSON:", e.message);
            console.log("Raw output:", data);
        }
    });

}).on('error', (err) => {
    console.error("Network Error:", err.message);
});
