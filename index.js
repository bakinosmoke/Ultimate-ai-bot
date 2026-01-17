// ==================== ULTIMATE AI BOT - ENTRY POINT ====================
// Optimized for Choreo Deployment
// =======================================================================

require('dotenv').config();
const express = require('express');
const fs = require('fs').promises;
const path = require('path');

const app = express();
const PORT = process.env.PORT || 8080;

// Health check endpoint (required by Choreo)
app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        service: 'ultimate-ai-bot',
        version: '2.0.0'
    });
});

// Root endpoint
app.get('/', (req, res) => {
    res.status(200).json({
        message: 'Ultimate AI Bot is running',
        endpoints: {
            health: '/health',
            status: '/status'
        },
        documentation: 'See README.md for API details'
    });
});

// Status endpoint
app.get('/status', async (req, res) => {
    try {
        const botStatus = {
            running: global.botInstance ? true : false,
            features: {
                tiktok_downloader: true,
                attack_system: true,
                ai_ceo: !!process.env.OPENAI_API_KEY,
                security_tools: true
            },
            environment: {
                node: process.version,
                platform: process.platform,
                memory: {
                    used: `${(process.memoryUsage().heapUsed / 1024 / 1024).toFixed(2)} MB`,
                    total: `${(process.memoryUsage().heapTotal / 1024 / 1024).toFixed(2)} MB`
                },
                uptime: `${process.uptime().toFixed(0)} seconds`
            }
        };
        
        res.status(200).json(botStatus);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Import and start the bot
async function startBot() {
    try {
        console.log('🚀 Starting Ultimate AI Bot...');
        
        // Validate environment
        const requiredEnvVars = ['BOT_TOKEN', 'ADMIN_ID'];
        const missingVars = requiredEnvVars.filter(varName => !process.env[varName]);
        
        if (missingVars.length > 0) {
            throw new Error(`Missing required environment variables: ${missingVars.join(', ')}`);
        }
        
        // Create necessary directories
        const directories = ['./data', './logs', './cache'];
        for (const dir of directories) {
            try {
                await fs.mkdir(dir, { recursive: true });
                console.log(`✅ Created directory: ${dir}`);
            } catch (err) {
                // Directory already exists
            }
        }
        
        // Start the bot
        const bot = require('./ultimate-ai-bot.js');
        global.botInstance = bot;
        
        console.log('✅ Bot started successfully');
        console.log(`👑 Admin ID: ${process.env.ADMIN_ID}`);
        console.log(`🤖 OpenAI: ${process.env.OPENAI_API_KEY ? 'Configured' : 'Not configured'}`);
        console.log(`🌐 Health endpoint: http://localhost:${PORT}/health`);
        
    } catch (error) {
        console.error('❌ Failed to start bot:', error);
        process.exit(1);
    }
}

// Start the server
const server = app.listen(PORT, () => {
    console.log(`📡 Server running on port ${PORT}`);
    console.log(`🔗 Health check: http://localhost:${PORT}/health`);
    
    // Start the bot after server is ready
    startBot().catch(error => {
        console.error('Failed to initialize bot:', error);
        process.exit(1);
    });
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('🛑 Received SIGTERM signal, shutting down gracefully...');
    
    if (global.botInstance && global.botInstance.stop) {
        try {
            global.botInstance.stop('SIGTERM');
        } catch (error) {
            console.error('Error stopping bot:', error);
        }
    }
    
    server.close(() => {
        console.log('✅ HTTP server closed');
        process.exit(0);
    });
    
    setTimeout(() => {
        console.error('⚠️ Forced shutdown after timeout');
        process.exit(1);
    }, 10000);
});

process.on('SIGINT', () => {
    console.log('🛑 Received SIGINT signal, shutting down...');
    
    if (global.botInstance && global.botInstance.stop) {
        try {
            global.botInstance.stop('SIGINT');
        } catch (error) {
            console.error('Error stopping bot:', error);
        }
    }
    
    server.close(() => {
        process.exit(0);
    });
});

// Export for testing
module.exports = app;