from flask import Flask, request, jsonify
from flask_cors import CORS
from datetime import datetime
import os
import psycopg2
from psycopg2.extras import RealDictCursor

app = Flask(__name__)
CORS(app)

# 👑 RANK SYSTEM - ADD YOUR USERNAMES HERE
RANKS = {
    "YourRobloxUsername": {"rank": "Owner", "emoji": "👑", "color": "#FFD700"},
    "FriendUsername": {"rank": "Co-Owner", "emoji": "⭐", "color": "#FF6B6B"},
    # Add more users below:
    # "AnotherFriend": {"rank": "Admin", "emoji": "🛡️", "color": "#4ECDC4"},
    # "Moderator1": {"rank": "Mod", "emoji": "🔧", "color": "#95E1D3"},
}

DEFAULT_RANK = {"rank": "Member", "emoji": "👤", "color": "#CCCCCC"}

def get_user_rank(username):
    """Get rank info for a user"""
    return RANKS.get(username, DEFAULT_RANK)

# Database connection
DATABASE_URL = os.environ.get('DATABASE_URL')

def get_db_connection():
    """Create database connection"""
    conn = psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)
    return conn

def init_database():
    """Initialize database table if it doesn't exist"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Create messages table with rank info
        cur.execute('''
            CREATE TABLE IF NOT EXISTS messages (
                id SERIAL PRIMARY KEY,
                username VARCHAR(50) NOT NULL,
                message TEXT NOT NULL,
                game VARCHAR(100) NOT NULL,
                rank VARCHAR(50),
                rank_emoji VARCHAR(10),
                rank_color VARCHAR(7),
                timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Create index for faster queries
        cur.execute('''
            CREATE INDEX IF NOT EXISTS idx_timestamp 
            ON messages(timestamp DESC)
        ''')
        
        conn.commit()
        cur.close()
        conn.close()
        print("✅ Database initialized successfully")
    except Exception as e:
        print(f"❌ Database initialization error: {e}")

@app.route('/', methods=['GET'])
def home():
    return jsonify({
        "status": "online",
        "service": "Universal Roblox Chat",
        "database": "PostgreSQL" if DATABASE_URL else "Not configured",
        "features": ["ranks", "persistent_storage"]
    })

@app.route('/send', methods=['POST'])
def send_message():
    """Endpoint to send a message"""
    try:
        data = request.get_json()
        
        if not data or 'username' not in data or 'message' not in data:
            return jsonify({"error": "Missing username or message"}), 400
        
        username = str(data['username'])[:50]
        message = str(data['message'])[:500]
        game = str(data.get('game', 'Unknown'))[:100]
        
        # Get user rank
        rank_info = get_user_rank(username)
        
        # Save to database
        conn = get_db_connection()
        cur = conn.cursor()
        
        cur.execute(
            '''INSERT INTO messages (username, message, game, rank, rank_emoji, rank_color) 
               VALUES (%s, %s, %s, %s, %s, %s) RETURNING id, timestamp''',
            (username, message, game, rank_info['rank'], rank_info['emoji'], rank_info['color'])
        )
        
        result = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({
            "success": True,
            "message": "Message sent",
            "data": {
                "id": result['id'],
                "username": username,
                "message": message,
                "game": game,
                "rank": rank_info['rank'],
                "rank_emoji": rank_info['emoji'],
                "rank_color": rank_info['color'],
                "timestamp": result['timestamp'].isoformat()
            }
        }), 201
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/messages', methods=['GET'])
def get_messages():
    """Endpoint to get messages"""
    try:
        since = request.args.get('since')
        limit = request.args.get('limit', 20, type=int)
        
        # Limit maximum messages per request
        limit = min(limit, 100)
        
        conn = get_db_connection()
        cur = conn.cursor()
        
        if since:
            # Get messages after specific timestamp
            cur.execute(
                '''SELECT id, username, message, game, rank, rank_emoji, rank_color, timestamp 
                   FROM messages WHERE timestamp > %s ORDER BY timestamp DESC LIMIT %s''',
                (since, limit)
            )
        else:
            # Get recent messages
            cur.execute(
                '''SELECT id, username, message, game, rank, rank_emoji, rank_color, timestamp 
                   FROM messages ORDER BY timestamp DESC LIMIT %s''',
                (limit,)
            )
        
        messages = cur.fetchall()
        
        # Convert to list and fix timestamp format
        messages_list = []
        for msg in reversed(messages):  # Reverse to show oldest first
            messages_list.append({
                "id": msg['id'],
                "username": msg['username'],
                "message": msg['message'],
                "game": msg['game'],
                "rank": msg['rank'] or "Member",
                "rank_emoji": msg['rank_emoji'] or "👤",
                "rank_color": msg['rank_color'] or "#CCCCCC",
                "timestamp": msg['timestamp'].isoformat()
            })
        
        cur.close()
        conn.close()
        
        return jsonify({
            "success": True,
            "count": len(messages_list),
            "messages": messages_list
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/ranks', methods=['GET'])
def get_ranks():
    """Get list of all ranks"""
    ranks_list = []
    for username, info in RANKS.items():
        ranks_list.append({
            "username": username,
            "rank": info['rank'],
            "emoji": info['emoji'],
            "color": info['color']
        })
    return jsonify({
        "ranks": ranks_list,
        "default": DEFAULT_RANK
    })

@app.route('/stats', methods=['GET'])
def get_stats():
    """Get chat statistics"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Total messages
        cur.execute('SELECT COUNT(*) as total FROM messages')
        total = cur.fetchone()['total']
        
        # Unique users
        cur.execute('SELECT COUNT(DISTINCT username) as users FROM messages')
        users = cur.fetchone()['users']
        
        # Messages today
        cur.execute('SELECT COUNT(*) as today FROM messages WHERE DATE(timestamp) = CURRENT_DATE')
        today = cur.fetchone()['today']
        
        cur.close()
        conn.close()
        
        return jsonify({
            "total_messages": total,
            "unique_users": users,
            "messages_today": today
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/clear', methods=['POST'])
def clear_messages():
    """Clear all messages (admin only)"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        cur.execute('DELETE FROM messages')
        deleted = cur.rowcount
        
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({
            "success": True,
            "deleted": deleted
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    # Initialize database on startup
    if DATABASE_URL:
        init_database()
    else:
        print("⚠️  WARNING: DATABASE_URL not set - messages will not persist!")
    
    port = int(os.environ.get('PORT', 10000))
    app.run(host='0.0.0.0', port=port)
