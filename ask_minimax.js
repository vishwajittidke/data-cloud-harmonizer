const https = require('https');
const readline = require('readline');

const API_KEY = "dahl_3Y6DwoV1mLW5MQacV1Q8JDiB2vtpNg4x2";
const API_URL = "https://inference.dahl.global/v1/chat/completions";
const MODEL = "MiniMaxAI/MiniMax-M2.7";

const args = process.argv.slice(2);
const messages = [{ role: "system", content: "You are a helpful coding assistant." }];

function sendMessage(prompt, callback) {
    messages.push({ role: "user", content: prompt });
    const data = JSON.stringify({ model: MODEL, messages: messages });
    const url = new URL(API_URL);
    const options = {
        hostname: url.hostname,
        path: url.pathname,
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${API_KEY}`,
            'Content-Length': Buffer.byteLength(data)
        }
    };
    
    const req = https.request(options, (res) => {
        let responseData = '';
        res.on('data', (chunk) => { responseData += chunk; });
        res.on('end', () => {
            try {
                const json = JSON.parse(responseData);
                if (json.choices && json.choices.length > 0) {
                    const reply = json.choices[0].message.content;
                    messages.push({ role: "assistant", content: reply });
                    callback(null, reply);
                } else {
                    callback(new Error(JSON.stringify(json)));
                }
            } catch (e) {
                callback(e);
            }
        });
    });
    
    req.on('error', (e) => callback(e));
    req.write(data);
    req.end();
}

if (args.length > 0) {
    // Single execution mode
    const prompt = args.join(" ");
    console.log(`\x1b[33mPrompt:\x1b[0m ${prompt}`);
    console.log(`\x1b[36mThinking...\x1b[0m`);
    sendMessage(prompt, (err, reply) => {
        if (err) console.error(`\x1b[31mError:\x1b[0m`, err);
        else console.log(`\n\x1b[32mMiniMax:\x1b[0m\n${reply}`);
    });
} else {
    // Interactive mode
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    console.log(`\x1b[36m=========================================\x1b[0m`);
    console.log(`\x1b[32m MiniMax AI Coding Assistant Initialized \x1b[0m`);
    console.log(`\x1b[36m=========================================\x1b[0m`);
    console.log(`Type 'exit' to quit.\n`);
    
    function askQuestion() {
        rl.question('\x1b[33mYou:\x1b[0m ', (prompt) => {
            if (prompt.toLowerCase() === 'exit' || prompt.toLowerCase() === 'quit') {
                console.log('\x1b[32mGoodbye!\x1b[0m');
                rl.close();
                return;
            }
            process.stdout.write('\x1b[36mMiniMax:\x1b[0m thinking...');
            sendMessage(prompt, (err, reply) => {
                process.stdout.write('\r\x1b[K'); // clear the line
                if (err) console.error(`\x1b[31mError:\x1b[0m`, err);
                else console.log(`\x1b[36mMiniMax:\x1b[0m\n${reply}\n`);
                askQuestion();
            });
        });
    }
    askQuestion();
}
