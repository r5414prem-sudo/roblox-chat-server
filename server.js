// ═══════════════════════════════════════════════════════════
//  🌐 UNIVERSAL ROBLOX CHAT SERVER - NODE.JS
//  High-performance backend with Express.js
//  Version 2.0.0
// ═══════════════════════════════════════════════════════════

const express = require('express');
const cors = require('cors');
const app = express();

// Configuration
const PORT = process.env.PORT || 10000;
const MAX_MESSAGES = 200;
const MAX_MESSAGE_LENGTH = 500;
const MAX_USERNAME_LENGTH = 50;
const MAX_GAME_LENGTH = 100;

// Middleware
app.use(cors()); // Enable CORS for all routes
app.use(express.json()); // Parse JSON bodies

// In-Memory Storage
const messages = [];
const activeUsers = new Map();
let totalMessages = 0;
const serverStartTime = new Date();

// ═══════════════════════════════════════════════════════════
//  UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════

/**
 * Sanitize and limit string length
 */
function sanitize(str, maxLength) {
    if (!str) return '';
    str = str.trim();
    return str.length > maxLength ? str.substring(0, maxLength) : str;
}

/**
 * Get current timestamp in ISO format
 */
function getTimestamp() {
    return new Date().toISOString();
}

/**
 * Calculate uptime in seconds
 */
function getUptime() {
    return Math.floor((new Date() - serverStartTime) / 1000);
}

/**
 * Update user activity
 */
function updateUserActivity(username, game) {
    if (!activeUsers.has(username)) {
        activeUsers.set(username, {
            username: username,
            lastGame: game,
            lastSeen: new Date(),
            messageCount: 1
        });
    } else {
        const user = activeUsers.get(username);
        user.lastGame = game;
        user.lastSeen = new Date();
        user.messageCount++;
    }
}

/**
 * Clean up inactive users (not seen in 10 minutes)
 */
function cleanupInactiveUsers() {
    const cutoffTime = new Date(Date.now() - 10 * 60 * 1000);
    let removedCount = 0;
    
    for (const [username, user] of activeUsers.entries()) {
        if (user.lastSeen < cutoffTime) {
            activeUsers.delete(username);
            removedCount++;
        }
    }
    
    if (removedCount > 0) {
        console.log(`🧹 Cleaned up ${removedCount} inactive users. Active: ${activeUsers.size}`);
    }
}

// Run cleanup every 5 minutes
setInterval(cleanupInactiveUsers, 5 * 60 * 1000);

// ═══════════════════════════════════════════════════════════
//  API ENDPOINTS
// ═══════════════════════════════════════════════════════════

/**
 * Home endpoint - Server info
 * GET /
 */
app.get('/', (req, res) => {
    res.json({
        status: 'online',
        service: 'Universal Roblox Chat',
        version: '2.0.0',
        language: 'Node.js',
        uptime_seconds: getUptime(),
        messages_stored: messages.length,
        active_users: activeUsers.size,
        total_messages: totalMessages
    });
});

/**
 * Send message endpoint
 * POST /send
 * Body: { username, message, game }
 */
app.post('/send', (req, res) => {
    try {
        const { username, message, game } = req.body;
        
        // Validate input
        if (!username || !message) {
            return res.status(400).json({
                error: 'Missing username or message'
            });
        }
        
        // Sanitize input
        const cleanUsername = sanitize(username, MAX_USERNAME_LENGTH);
        const cleanMessage = sanitize(message, MAX_MESSAGE_LENGTH);
        const cleanGame = sanitize(game || 'Unknown', MAX_GAME_LENGTH);
        
        if (!cleanUsername || !cleanMessage) {
            return res.status(400).json({
                error: 'Username and message cannot be empty'
            });
        }
        
        // Create message object
        totalMessages++;
        const msg = {
            id: totalMessages,
            username: cleanUsername,
            message: cleanMessage,
            game: cleanGame,
            timestamp: getTimestamp()
        };
        
        // Store message (keep only last MAX_MESSAGES)
        messages.push(msg);
        if (messages.length > MAX_MESSAGES) {
            messages.shift();
        }
        
        // Update user activity
        updateUserActivity(cleanUsername, cleanGame);
        
        // Log message
        console.log(`📨 [${cleanGame}] ${cleanUsername}: ${cleanMessage}`);
        
        // Send response
        res.status(201).json({
            success: true,
            message: 'Message sent',
            data: msg
        });
        
    } catch (error) {
        console.error('❌ Send error:', error);
        res.status(500).json({
            error: 'Internal server error: ' + error.message
        });
    }
});

/**
 * Get messages endpoint
 * GET /messages?since=TIMESTAMP&limit=20
 */
app.get('/messages', (req, res) => {
    try {
        const { since, limit = '20' } = req.query;
        const maxLimit = Math.min(parseInt(limit) || 20, MAX_MESSAGES);
        
        // Filter messages
        let filtered = messages;
        
        if (since) {
            filtered = messages.filter(m => m.timestamp > since);
        }
        
        // Get last N messages
        const recent = filtered.slice(-maxLimit);
        
        res.json({
            success: true,
            count: recent.length,
            messages: recent
        });
        
    } catch (error) {
        console.error('❌ Get messages error:', error);
        res.status(500).json({
            error: 'Internal server error: ' + error.message
        });
    }
});

/**
 * Statistics endpoint
 * GET /stats
 */
app.get('/stats', (req, res) => {
    const uptime = getUptime();
    
    res.json({
        total_messages: totalMessages,
        unique_users: activeUsers.size,
        messages_in_memory: messages.length,
        uptime_hours: (uptime / 3600).toFixed(2),
        server_start: serverStartTime.toISOString()
    });
});

/**
 * Clear messages endpoint
 * POST /clear
 */
app.post('/clear', (req, res) => {
    const deleted = messages.length;
    messages.length = 0; // Clear array
    
    console.log(`🗑️  Cleared ${deleted} messages`);
    
    res.json({
        success: true,
        deleted: deleted,
        message: 'All messages cleared'
    });
});

/**
 * Health check endpoint
 * GET /health
 */
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: getTimestamp()
    });
});

// ═══════════════════════════════════════════════════════════
//  ERROR HANDLERS
// ═══════════════════════════════════════════════════════════

// 404 handler
app.use((req, res) => {
    res.status(404).json({
        error: 'Endpoint not found'
    });
});

// Global error handler
app.use((err, req, res, next) => {
    console.error('❌ Server error:', err);
    res.status(500).json({
        error: 'Internal server error'
    });
});

// ═══════════════════════════════════════════════════════════
//  SERVER STARTUP
// ═══════════════════════════════════════════════════════════

app.listen(PORT, () => {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('  🌐 UNIVERSAL ROBLOX CHAT SERVER');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`  Version: 2.0.0`);
    console.log(`  Language: Node.js ${process.version}`);
    console.log('  Storage: In-Memory');
    console.log(`  Max Messages: ${MAX_MESSAGES}`);
    console.log('  CORS: Enabled');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`🌐 Local: http://localhost:${PORT}`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('👋 Received SIGTERM, shutting down gracefully...');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('\n👋 Received SIGINT, shutting down gracefully...');
    process.exit(0);
});
