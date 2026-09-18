const admin = require('firebase-admin');
const functions = require('firebase-functions');
require('firebase-functions/params').defineString = () => ({ value: () => 'fake_api_key' });

const index = require('./index.js');

let fetchCallCount = 0;
global.fetch = async (url, options) => {
    fetchCallCount++;
    console.log(`Fetch called [${fetchCallCount}]: ${url}`);
    
    if (fetchCallCount === 1) {
        console.log("Simulating 500");
        return { ok: false, status: 500, text: async () => JSON.stringify({ error: "Server Error" }) };
    }
    if (fetchCallCount === 2) {
        console.log("Simulating 429");
        return { ok: false, status: 429, text: async () => JSON.stringify({ error: "Rate limit exceeded" }) };
    }
    
    console.log("Simulating 200");
    return {
        ok: true,
        status: 200,
        text: async () => JSON.stringify({
            candidates: [{ content: { parts: [{ text: "{ \"comercio\": \"Test\" }" }] } }]
        })
    };
};

const context = { auth: { uid: 'test' } };
const data = { imageBase64: 'base64string' };

async function run() {
    try {
        console.log("Running handler...");
        const result = await index.analyzeReceipt.run(data, context);
        console.log("Success:", result);
    } catch (err) {
        console.error("Error:", err);
    }
}
run();
