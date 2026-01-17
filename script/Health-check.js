#!/usr/bin/env node
/**
 * Ultimate AI Bot - Health Check Script
 * Monitors bot health and system status
 */

const http = require('http');
const fs = require('fs').promises;
const path = require('path');

const HEALTH_ENDPOINT = process.env.HEALTH_ENDPOINT || 'http://localhost:8080/health';
const STATUS_ENDPOINT = process.env.STATUS_ENDPOINT || 'http://localhost:8080/status';
const CHECK_INTERVAL = process.env.CHECK_INTERVAL || 30000; // 30 seconds
const LOG_FILE = path.join(__dirname, '../logs/health-check.log');

// ANSI color codes for terminal
const COLORS = {
    RESET: '\x1b[0m',
    RED: '\x1b[31m',
    GREEN: '\x1b[32m',
    YELLOW: '\x1b[33m',
    BLUE: '\x1b[36m',
    MAGENTA: '\x1b[35m'
};

async function logToFile(message) {
    const timestamp = new Date().toISOString();
    const logMessage = `[${timestamp}] ${message}\n`;
    
    try {
        await fs.appendFile(LOG_FILE, logMessage);
    } catch (error) {
        console.error('Failed to write log:', error.message);
    }
}

async function checkHealth() {
    const startTime = Date.now();
    
    try {
        // Check health endpoint
        const healthResponse = await httpRequest(HEALTH_ENDPOINT);
        const healthTime = Date.now() - startTime;
        
        if (!healthResponse.success) {
            return {
                success: false,
                endpoint: 'health',
                error: healthResponse.error,
                responseTime: healthTime
            };
        }
        
        // Check status endpoint
        const statusResponse = await httpRequest(STATUS_ENDPOINT);
        const totalTime = Date.now() - startTime;
        
        if (!statusResponse.success) {
            return {
                success: false,
                endpoint: 'status',
                error: statusResponse.error,
                responseTime: totalTime
            };
        }
        
        // Check system resources
        const systemStats = await getSystemStats();
        
        return {
            success: true,
            responseTime: totalTime,
            health: healthResponse.data,
            status: statusResponse.data,
            system: systemStats,
            timestamp: new Date().toISOString()
        };
        
    } catch (error) {
        return {
            success: false,
            error: error.message,
            responseTime: Date.now() - startTime
        };
    }
}

function httpRequest(url) {
    return new Promise((resolve) => {
        const req = http.get(url, { timeout: 5000 }, (res) => {
            let data = '';
            
            res.on('data', (chunk) => {
                data += chunk;
            });
            
            res.on('end', () => {
                try {
                    const parsed = JSON.parse(data);
                    resolve({
                        success: true,
                        status: res.statusCode,
                        data: parsed
                    });
                } catch (error) {
                    resolve({
                        success: false,
                        error: 'Invalid JSON response'
                    });
                }
            });
        });
        
        req.on('error', (error) => {
            resolve({
                success: false,
                error: error.message
            });
        });
        
        req.on('timeout', () => {
            req.destroy();
            resolve({
                success: false,
                error: 'Request timeout'
            });
        });
    });
}

async function getSystemStats() {
    const stats = {
        memory: process.memoryUsage(),
        uptime: process.uptime(),
        cpu: process.cpuUsage(),
        pid: process.pid,
        platform: process.platform,
        nodeVersion: process.version
    };
    
    // Check disk space if available
    try {
        const fs = require('fs');
        const disk = require('check-disk-space').default;
        
        if (fs.existsSync('/')) {
            const diskInfo = await disk('/');
            stats.disk = diskInfo;
        }
    } catch (error) {
        // Disk check not available
    }
    
    return stats;
}

function formatBytes(bytes) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function formatTime(seconds) {
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = Math.floor(seconds % 60);
    
    const parts = [];
    if (days > 0) parts.push(`${days}d`);
    if (hours > 0) parts.push(`${hours}h`);
    if (minutes > 0) parts.push(`${minutes}m`);
    if (secs > 0 || parts.length === 0) parts.push(`${secs}s`);
    
    return parts.join(' ');
}

async function displayHealthStatus(result) {
    const timestamp = new Date().toLocaleTimeString();
    
    if (result.success) {
        console.log(`\n${COLORS.GREEN}╔════════════════════════════════════════════════╗${COLORS.RESET}`);
        console.log(`${COLORS.GREEN}║  ✅ HEALTH CHECK PASSED - ${timestamp} ║${COLORS.RESET}`);
        console.log(`${COLORS.GREEN}╚════════════════════════════════════════════════╝${COLORS.RESET}`);
        
        console.log(`\n${COLORS.BLUE}📡 Endpoints:${COLORS.RESET}`);
        console.log(`  • Health: ${HEALTH_ENDPOINT} ${COLORS.GREEN}✅${COLORS.RESET}`);
        console.log(`  • Status: ${STATUS_ENDPOINT} ${COLORS.GREEN}✅${COLORS.RESET}`);
        
        console.log(`\n${COLORS.BLUE}⚡ Performance:${COLORS.RESET}`);
        console.log(`  • Response Time: ${result.responseTime}ms`);
        console.log(`  • Bot Status: ${result.status.running ? 'Running' : 'Stopped'}`);
        
        console.log(`\n${COLORS.BLUE}💾 Memory Usage:${COLORS.RESET}`);
        console.log(`  • Used: ${formatBytes(result.system.memory.heapUsed)}`);
        console.log(`  • Total: ${formatBytes(result.system.memory.heapTotal)}`);
        console.log(`  • RSS: ${formatBytes(result.system.memory.rss)}`);
        
        console.log(`\n${COLORS.BLUE}🕒 Uptime:${COLORS.RESET}`);
        console.log(`  • Process: ${formatTime(result.system.uptime)}`);
        if (result.health?.timestamp) {
            const uptime = Math.floor((new Date() - new Date(result.health.timestamp)) / 1000);
            console.log(`  • Service: ${formatTime(uptime)}`);
        }
        
        console.log(`\n${COLORS.BLUE}🤖 Bot Features:${COLORS.RESET}`);
        const features = result.status?.features || {};
        Object.entries(features).forEach(([feature, enabled]) => {
            console.log(`  • ${feature}: ${enabled ? '✅' : '❌'}`);
        });
        
        // Check for warnings
        const warnings = [];
        if (result.system.memory.heapUsed / result.system.memory.heapTotal > 0.8) {
            warnings.push('High memory usage detected');
        }
        
        if (result.responseTime > 1000) {
            warnings.push('Slow response time');
        }
        
        if (warnings.length > 0) {
            console.log(`\n${COLORS.YELLOW}⚠️  Warnings:${COLORS.RESET}`);
            warnings.forEach(warning => console.log(`  • ${warning}`));
        }
        
    } else {
        console.log(`\n${COLORS.RED}╔════════════════════════════════════════════════╗${COLORS.RESET}`);
        console.log(`${COLORS.RED}║  ❌ HEALTH CHECK FAILED - ${timestamp}  ║${COLORS.RESET}`);
        console.log(`${COLORS.RED}╚════════════════════════════════════════════════╝${COLORS.RESET}`);
        
        console.log(`\n${COLORS.RED}🔴 Error Details:${COLORS.RESET}`);
        console.log(`  • Endpoint: ${result.endpoint || 'Unknown'}`);
        console.log(`  • Error: ${result.error}`);
        console.log(`  • Response Time: ${result.responseTime}ms`);
        
        console.log(`\n${COLORS.YELLOW}🔧 Troubleshooting Steps:${COLORS.RESET}`);
        console.log(`  1. Check if bot is running: ps aux | grep node`);
        console.log(`  2. Check port 8080: netstat -tuln | grep 8080`);
        console.log(`  3. Check logs: tail -f logs/errors.log`);
        console.log(`  4. Restart bot: npm start`);
    }
    
    // Log to file
    const logMessage = result.success 
        ? `Health check passed - Response: ${result.responseTime}ms - Memory: ${formatBytes(result.system.memory.heapUsed)}`
        : `Health check failed - Error: ${result.error} - Endpoint: ${result.endpoint}`;
    
    await logToFile(logMessage);
}

async function continuousMonitoring() {
    console.log(`${COLORS.MAGENTA}
╔════════════════════════════════════════════════╗
║    🤖 ULTIMATE AI BOT - HEALTH MONITORING     ║
║            🇰🇭 POWERED BY CAMBODIA 🇰🇭         ║
╚════════════════════════════════════════════════╝${COLORS.RESET}
    `);
    
    console.log(`${COLORS.BLUE}🔍 Starting continuous health monitoring...${COLORS.RESET}`);
    console.log(`📊 Check interval: ${CHECK_INTERVAL / 1000} seconds`);
    console.log(`📁 Log file: ${LOG_FILE}`);
    console.log(`${COLORS.BLUE}────────────────────────────────────────────${COLORS.RESET}\n`);
    
    let consecutiveFailures = 0;
    const MAX_FAILURES = 3;
    
    while (true) {
        const result = await checkHealth();
        await displayHealthStatus(result);
        
        if (result.success) {
            consecutiveFailures = 0;
        } else {
            consecutiveFailures++;
            
            if (consecutiveFailures >= MAX_FAILURES) {
                console.log(`\n${COLORS.RED}🚨 CRITICAL: ${MAX_FAILURES} consecutive failures detected!${COLORS.RESET}`);
                console.log(`${COLORS.YELLOW}⚠️  Bot may need manual intervention${COLORS.RESET}`);
                
                await logToFile(`CRITICAL: ${MAX_FAILURES} consecutive failures detected`);
            }
        }
        
        console.log(`${COLORS.BLUE}────────────────────────────────────────────${COLORS.RESET}`);
        console.log(`⏳ Next check in ${CHECK_INTERVAL / 1000} seconds...\n`);
        
        await new Promise(resolve => setTimeout(resolve, CHECK_INTERVAL));
    }
}

async function singleCheck() {
    console.log(`${COLORS.MAGENTA}🔍 Running single health check...${COLORS.RESET}\n`);
    
    const result = await checkHealth();
    await displayHealthStatus(result);
    
    // Exit with appropriate code
    process.exit(result.success ? 0 : 1);
}

// Parse command line arguments
const args = process.argv.slice(2);
const mode = args[0] || 'continuous';

if (mode === 'single' || mode === '--single' || mode === '-s') {
    singleCheck().catch(error => {
        console.error(`${COLORS.RED}Error during health check:${COLORS.RESET}`, error);
        process.exit(1);
    });
} else {
    continuousMonitoring().catch(error => {
        console.error(`${COLORS.RED}Monitoring error:${COLORS.RESET}`, error);
        process.exit(1);
    });
}

// Handle graceful shutdown
process.on('SIGINT', () => {
    console.log(`\n${COLORS.YELLOW}🛑 Health monitoring stopped${COLORS.RESET}`);
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log(`\n${COLORS.YELLOW}🛑 Health monitoring terminated${COLORS.RESET}`);
    process.exit(0);
});
