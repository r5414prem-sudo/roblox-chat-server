// ═══════════════════════════════════════════════════════════
//  🌐 UNIVERSAL ROBLOX CHAT SERVER
//  Clean, Organized & Well-Documented
//  Version 2.1.0
// ═══════════════════════════════════════════════════════════

const express = require('express');
const cors = require('cors');
const app = express();

// ═══════════════════════════════════════════════════════════
//  ⚙️ CONFIGURATION
// ═══════════════════════════════════════════════════════════

const CONFIG = {
    PORT: process.env.PORT || 10000,
    MAX_MESSAGES: 1000,              // Increased from 200
    MAX_MESSAGE_LENGTH: 500,
    MAX_USERNAME_LENGTH: 50,
    MAX_GAME_LENGTH: 100,
    CLEANUP_INTERVAL: 5 * 60 * 1000, // 5 minutes
    USER_TIMEOUT: 10 * 60 * 1000     // 10 minutes
};

// ═══════════════════════════════════════════════════════════
//  📦 MIDDLEWARE
// ═══════════════════════════════════════════════════════════

app.use(cors());           // Enable CORS for Roblox
app.use(express.json());   // Parse JSON request bodies

// Request logger
app.use((req, res, next) => {
    console.log(`${req.method} ${req.path} - ${new Date().toISOString()}`);
    next();
});

// ═══════════════════════════════════════════════════════════
//  💾 DATA STORAGE
// ═══════════════════════════════════════════════════════════

const storage = {
    messages: [],
    activeUsers: new Map(),
    totalMessagesSent: 0,
    serverStartTime: new Date()
};

// ═══════════════════════════════════════════════════════════
//  🛠️ UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════

const utils = {
    /**
     * Sanitize and trim string to max length
     */
    sanitize(str, maxLength) {
        if (!str) return '';
        str = str.trim();
        return str.length > maxLength ? str.substring(0, maxLength) : str;
    },

    /**
     * Get current timestamp in ISO format
     */
    getTimestamp() {
        return new Date().toISOString();
    },

    /**
     * Get Unix timestamp in seconds
     */
    getUnixTimestamp() {
        return Math.floor(Date.now() / 1000);
    },

    /**
     * Calculate server uptime in seconds
     */
    getUptime() {
        return Math.floor((Date.now() - storage.serverStartTime) / 1000);
    },

    /**
     * Format uptime as human-readable string
     */
    formatUptime(seconds) {
        const days = Math.floor(seconds / 86400);
        const hours = Math.floor((seconds % 86400) / 3600);
        const mins = Math.floor((seconds % 3600) / 60);
        return `${days}d ${hours}h ${mins}m`;
    }
};

// ═══════════════════════════════════════════════════════════
//  👥 USER MANAGEMENT
// ═══════════════════════════════════════════════════════════

const userManager = {
    /**
     * Update user activity
     */
    updateActivity(username, game, userId) {
        if (!storage.activeUsers.has(username)) {
            storage.activeUsers.set(username, {
                username: username,
                userId: userId,
                firstSeen: new Date(),
                lastSeen: new Date(),
                lastGame: game,
                messageCount: 1
            });
            console.log(`👤 New user: ${username}`);
        } else {
            const user = storage.activeUsers.get(username);
            user.lastSeen = new Date();
            user.lastGame = game;
            user.messageCount++;
        }
    },

    /**
     * Remove inactive users
     */
    cleanupInactive() {
        const cutoffTime = Date.now() - CONFIG.USER_TIMEOUT;
        let removedCount = 0;

        for (const [username, user] of storage.activeUsers.entries()) {
            if (user.lastSeen.getTime() < cutoffTime) {
                storage.activeUsers.delete(username);
                removedCount++;
            }
        }

        if (removedCount > 0) {
            console.log(`🧹 Cleaned up ${removedCount} inactive users. Active: ${storage.activeUsers.size}`);
        }
    },

    /**
     * Get list of active users
     */
    getActiveUsers() {
        return Array.from(storage.activeUsers.values());
    }
};

// Start periodic cleanup
setInterval(() => userManager.cleanupInactive(), CONFIG.CLEANUP_INTERVAL);

// ═══════════════════════════════════════════════════════════
//  💬 MESSAGE MANAGEMENT
// ═══════════════════════════════════════════════════════════

const messageManager = {
    /**
     * Add new message to storage
     */
    addMessage(username, message, game, userId) {
        storage.totalMessagesSent++;

        const msg = {
            id: storage.totalMessagesSent,
            username: username,
            message: message,
            game: game,
            userId: userId,
            timestamp: utils.getUnixTimestamp()
        };

        // Add to storage
        storage.messages.push(msg);

        // Keep only last MAX_MESSAGES
        if (storage.messages.length > CONFIG.MAX_MESSAGES) {
            storage.messages.shift();
        }

        // Update user activity
        userManager.updateActivity(username, game, userId);

        console.log(`📨 [${game}] ${username}: ${message}`);

        return msg;
    },

    /**
     * Get messages since a timestamp
     */
    getMessagesSince(sinceTimestamp, limit = 50) {
        let filtered = storage.messages;

        if (sinceTimestamp) {
            const since = parseFloat(sinceTimestamp);
            filtered = storage.messages.filter(m => m.timestamp > since);
        }

        // Return last N messages
        const maxLimit = Math.min(limit, CONFIG.MAX_MESSAGES);
        return filtered.slice(-maxLimit);
    },

    /**
     * Clear all messages
     */
    clearAll() {
        const count = storage.messages.length;
        storage.messages = [];
        console.log(`🗑️  Cleared ${count} messages`);
        return count;
    },

    /**
     * Get message statistics
     */
    getStats() {
        return {
            total_messages_sent: storage.totalMessagesSent,
            messages_in_storage: storage.messages.length,
            active_users: storage.activeUsers.size,
            uptime_seconds: utils.getUptime(),
            uptime_formatted: utils.formatUptime(utils.getUptime()),
            server_started: storage.serverStartTime.toISOString()
        };
    }
};

// ═══════════════════════════════════════════════════════════
//  🔐 VALIDATION
// ═══════════════════════════════════════════════════════════

const validator = {
    /**
     * Validate message send request
     */
    validateSendRequest(body) {
        const errors = [];

        if (!body.username) errors.push('username is required');
        if (!body.message) errors.push('message is required');
        if (body.message && body.message.trim().length === 0) {
            errors.push('message cannot be empty');
        }
        if (body.message && body.message.length > CONFIG.MAX_MESSAGE_LENGTH) {
            errors.push(`message exceeds ${CONFIG.MAX_MESSAGE_LENGTH} characters`);
        }

        return {
            valid: errors.length === 0,
            errors: errors
        };
    }
};

// ═══════════════════════════════════════════════════════════
//  🌐 API ROUTES
// ═══════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────
// GET / - Server Information
// ─────────────────────────────────────────────────────────
app.get('/', (req, res) => {
    res.json({
        status: 'online',
        service: 'Universal Roblox Chat',
        version: '2.1.0',
        storage: 'In-Memory',
        config: {
            max_messages: CONFIG.MAX_MESSAGES,
            max_message_length: CONFIG.MAX_MESSAGE_LENGTH
        },
        stats: messageManager.getStats()
    });
});

// ─────────────────────────────────────────────────────────
// POST /send - Send a new message
// ─────────────────────────────────────────────────────────
app.post('/send', (req, res) => {
    try {
        // Validate request
        const validation = validator.validateSendRequest(req.body);
        if (!validation.valid) {
            return res.status(400).json({
                success: false,
                error: 'Validation failed',
                details: validation.errors
            });
        }

        // Sanitize input
        const username = utils.sanitize(req.body.username, CONFIG.MAX_USERNAME_LENGTH);
        const message = utils.sanitize(req.body.message, CONFIG.MAX_MESSAGE_LENGTH);
        const game = utils.sanitize(req.body.game || 'Unknown Game', CONFIG.MAX_GAME_LENGTH);
        const userId = req.body.userId || 'unknown';

        // Add message
        const msg = messageManager.addMessage(username, message, game, userId);

        // Send response
        res.status(201).json({
            success: true,
            message: 'Message sent successfully',
            data: msg
        });

    } catch (error) {
        console.error('❌ Send error:', error);
        res.status(500).json({
            success: false,
            error: 'Internal server error',
            details: error.message
        });
    }
});

// ─────────────────────────────────────────────────────────
// GET /messages - Retrieve messages
// ─────────────────────────────────────────────────────────
app.get('/messages', (req, res) => {
    try {
        const since = req.query.since;
        const limit = parseInt(req.query.limit) || 50;

        const messages = messageManager.getMessagesSince(since, limit);

        res.json({
            success: true,
            count: messages.length,
            messages: messages,
            onlineUsers: storage.activeUsers.size
        });

    } catch (error) {
        console.error('❌ Get messages error:', error);
        res.status(500).json({
            success: false,
            error: 'Internal server error',
            details: error.message
        });
    }
});

// ─────────────────────────────────────────────────────────
// GET /stats - Server statistics
// ─────────────────────────────────────────────────────────
app.get('/stats', (req, res) => {
    res.json({
        success: true,
        stats: messageManager.getStats()
    });
});

// ─────────────────────────────────────────────────────────
// GET /users - Active users list
// ─────────────────────────────────────────────────────────
app.get('/users', (req, res) => {
    const users = userManager.getActiveUsers();
    res.json({
        success: true,
        count: users.length,
        users: users
    });
});

// ─────────────────────────────────────────────────────────
// POST /clear - Clear all messages (Admin)
// ─────────────────────────────────────────────────────────
app.post('/clear', (req, res) => {
    const deleted = messageManager.clearAll();
    
    res.json({
        success: true,
        deleted: deleted,
        message: 'All messages cleared'
    });
});

// ─────────────────────────────────────────────────────────
// GET /health - Health check
// ─────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: utils.getTimestamp(),
        uptime: utils.getUptime()
    });
});

// ─────────────────────────────────────────────────────────
// GET /ping - Simple ping
// ─────────────────────────────────────────────────────────
app.get('/ping', (req, res) => {
    res.json({ pong: true });
});

// ═══════════════════════════════════════════════════════════
//  ❌ ERROR HANDLERS
// ═══════════════════════════════════════════════════════════

// 404 - Route not found
app.use((req, res) => {
    res.status(404).json({
        success: false,
        error: 'Endpoint not found',
        path: req.path
    });
});

// 500 - Internal server error
app.use((err, req, res, next) => {
    console.error('❌ Unhandled error:', err);
    res.status(500).json({
        success: false,
        error: 'Internal server error'
    });
});

// ═══════════════════════════════════════════════════════════
//  🚀 SERVER STARTUP
// ═══════════════════════════════════════════════════════════

const server = app.listen(CONFIG.PORT, () => {
    console.log('\n');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('  🌐 UNIVERSAL ROBLOX CHAT SERVER');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`  📦 Version: 2.1.0`);
    console.log(`  🔧 Node.js: ${process.version}`);
    console.log(`  💾 Storage: In-Memory`);
    console.log(`  📝 Max Messages: ${CONFIG.MAX_MESSAGES}`);
    console.log(`  🔒 CORS: Enabled`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`  🚀 Server: http://localhost:${CONFIG.PORT}`);
    console.log(`  📊 Status: http://localhost:${CONFIG.PORT}/`);
    console.log(`  💬 Messages: http://localhost:${CONFIG.PORT}/messages`);
    console.log(`  📈 Stats: http://localhost:${CONFIG.PORT}/stats`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`  ⏰ Started: ${storage.serverStartTime.toISOString()}`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
});

// ═══════════════════════════════════════════════════════════
//  🛑 GRACEFUL SHUTDOWN
// ═══════════════════════════════════════════════════════════

const shutdown = (signal) => {
    console.log(`\n👋 Received ${signal}, shutting down gracefully...`);
    
    server.close(() => {
        console.log('✅ Server closed');
        console.log(`📊 Final stats: ${storage.totalMessagesSent} total messages sent`);
        process.exit(0);
    });

    // Force shutdown after 10 seconds
    setTimeout(() => {
        console.error('⚠️  Forced shutdown after timeout');
        process.exit(1);
    }, 10000);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// ═══════════════════════════════════════════════════════════
//  📝 EXPORTS (for testing)
// ═══════════════════════════════════════════════════════════

module.exports = {
    app,
    storage,
    messageManager,
    userManager,
    utils
};
                   
