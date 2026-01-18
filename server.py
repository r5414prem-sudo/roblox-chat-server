from flask import Flask, request, jsonify
from flask_cors import CORS
from datetime import datetime
import os
import psycopg2
from psycopg2.extras import RealDictCursor

app = Flask(__name__)
CORS(app)

# 👑 RANK SYSTEM - YOUR ACTUAL USERNAMES
RANKS = {
    "foffasfieifro": {"rank": "Owner", "emoji": "👑", "color": "#FFD700", "level": 3},
    "Ya_shumi09": {"rank": "Owner", "emoji": "👑", "color": "#FFD700", "level": 3},
    "shimul2222222": {"rank": "Mod", "emoji": "🛡️", "color": "#4ECDC4", "level": 2},
}

DEFAULT_RANK = {"rank": "Member", "emoji": "👤", "color": "#CCCCCC", "level": 0}

# Banned users list (muted)
BANNED_USERS = set()

def get_user_rank(username):
    """Get rank info for a user"""
    return RANKS.get(username, DEFAULT_RANK)

def is_staff(username):
    """Check if user is staff (Owner or Mod)"""
    rank_info = get_user_rank(username)
    return rank_info.get('level', 0) >= 2

def is_owner(username):
    """Check if user is Owner"""
    rank_info = get_user_rank(username)
    return rank_info.get('level', 0) >= 3

# Database connection
DATABASE_URL = os.environ.get('DATABASE_URL')

# ✅ FIX: Convert postgres:// to postgresql:// for psycopg2
if DATABASE_URL and DATABASE_URL.startswith('postgres://'):
    DATABASE_URL = DATABASE_URL.replace('postgres://', 'postgresql://', 1)
    print("✅ Fixed DATABASE_URL format (postgres:// → postgresql://)")

def get_db_connection():
    """Create database connection"""
    if not DATABASE_URL:
        print("❌ DATABASE_URL is not set")
        return None
    try:
        conn = psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)
        return conn
    except Exception as e:
        print(f"❌ Database connection error: {e}")
        return None

def init_database():
    """Initialize database table if it doesn't exist"""
    if not DATABASE_URL:
        print("⚠️  WARNING: DATABASE_URL not set - skipping database initialization")
        return False
    
    try:
        conn = get_db_connection()
        if not conn:
            print("❌ Could not connect to database")
            return False
            
        cur = conn.cursor()
        
        print("📦 Creating messages table...")
        # Create messages table
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
        
        print("📦 Creating banned_users table...")
        # Create banned users table
        cur.execute('''
            CREATE TABLE IF NOT EXISTS banned_users (
                username VARCHAR(50) PRIMARY KEY,
                banned_by VARCHAR(50),
                reason TEXT,
                banned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        print("📦 Creating indexes...")
        # Create index for faster queries
        cur.execute('''
            CREATE INDEX IF NOT EXISTS idx_timestamp 
            ON messages(timestamp DESC)
        ''')
        
        conn.commit()
        cur.close()
        conn.close()
        print("✅ Database initialized successfully!")
        return True
    except Exception as e:
        print(f"❌ Database initialization error: {e}")
        import traceback
        traceback.print_exc()
        return False

@app.route('/', methods=['GET'])
def home():
    return jsonify({
        "status": "online",
        "service": "Universal Roblox Chat",
        "database": "PostgreSQL Connected" if DATABASE_URL else "Not configured",
        "features": ["ranks", "persistent_storage", "moderation"],
        "version": "2.0"
    })

@app.route('/setup', methods=['GET'])
def setup_database():
    """Manually trigger database setup"""
    print("🔧 Manual database setup triggered...")
    if init_database():
        return jsonify({
            "success": True,
            "message": "Database initialized successfully"
        })
    else:
        return jsonify({
            "success": False,
            "message": "Database initialization failed - check logs"
        }), 500

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
        
        # Check if user is banned
        if username in BANNED_USERS:
            return jsonify({"error": "You are muted from the chat"}), 403
        
        # Check database for banned users
        conn = get_db_connection()
        if conn:
            cur = conn.cursor()
            cur.execute('SELECT username FROM banned_users WHERE username = %s', (username,))
            if cur.fetchone():
                cur.close()
                conn.close()
                BANNED_USERS.add(username)
                return jsonify({"error": "You are muted from the chat"}), 403
            cur.close()
            conn.close()
        
        # Get user rank
        rank_info = get_user_rank(username)
        
        # Save to database
        conn = get_db_connection()
        if not conn:
            return jsonify({"error": "Database connection failed"}), 500
            
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
        print(f"❌ Send message error: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/messages', methods=['GET'])
def get_messages():
    """Endpoint to get messages"""
    try:
        since = request.args.get('since')
        limit = request.args.get('limit', 20, type=int)
        
        limit = min(limit, 100)
        
        conn = get_db_connection()
        if not conn:
            return jsonify({"error": "Database connection failed"}), 500
            
        cur = conn.cursor()
        
        if since:
            cur.execute(
                '''SELECT id, username, message, game, rank, rank_emoji, rank_color, timestamp 
                   FROM messages WHERE timestamp > %s ORDER BY timestamp DESC LIMIT %s''',
                (since, limit)
            )
        else:
            cur.execute(
                '''SELECT id, username, message, game, rank, rank_emoji, rank_color, timestamp 
                   FROM messages ORDER BY timestamp DESC LIMIT %s''',
                (limit,)
            )
        
        messages = cur.fetchall()
        
        messages_list = []
        for msg in reversed(messages):
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
        print(f"❌ Get messages error: {e}")
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
        if not conn:
            return jsonify({"error": "Database connection failed"}), 500
            
        cur = conn.cursor()
        
        cur.execute('SELECT COUNT(*) as total FROM messages')
        total = cur.fetchone()['total']
        
        cur.execute('SELECT COUNT(DISTINCT username) as users FROM messages')
        users = cur.fetchone()['users']
        
        cur.execute('SELECT COUNT(*) as today FROM messages WHERE DATE(timestamp) = CURRENT_DATE')
        today = cur.fetchone()['today']
        
        cur.execute('SELECT COUNT(*) as banned FROM banned_users')
        banned = cur.fetchone()['banned']
        
        cur.close()
        conn.close()
        
        return jsonify({
            "total_messages": total,
            "unique_users": users,
            "messages_today": today,
            "banned_users": banned
        })
        
    except Exception as e:
        print(f"❌ Stats error: {e}")
        return jsonify({"error": str(e)}), 500

# ============ MODERATION ENDPOINTS (Staff Only) ============

@app.route('/clear', methods=['POST'])
def clear_messages():
    """Clear all messages (Staff only)"""
    try:
        data = request.get_json()
        username = data.get('username')
        
        if not username or not is_staff(username):
            return jsonify({"error": "Unauthorized - Staff only"}), 403
        
        conn = get_db_connection()
        if not conn:
            return jsonify({"error": "Database connection failed"}), 500
            
        cur = conn.cursor()
        
        cur.execute('DELETE FROM messages')
        deleted = cur.rowcount
        
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({
            "success": True,
            "deleted": deleted,
            "cleared_by": username
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/mute', methods=['POST'])
def mute_user():
    """Mute/ban a user from chat (Staff only)"""
    try:
        data = request.get_json()
        moderator = data.get('moderator')
        target_user = data.get('target_user')
        reason = data.get('reason', 'No reason provided')
        
        if not moderator or not is_staff(moderator):
            return jsonify({"error": "Unauthorized - Staff only"}), 403
        
        if not target_user:
            return jsonify({"error": "Missing target_user"}), 400
        
        # Can't ban staff members
        if is_staff(target_user):
            return jsonify({"error": "Cannot mute staff members"}), 400
        
        conn = get_db_connection()
        if not conn:
            return jsonify({"error": "Database connection failed"}), 500
            
        cur = conn.cursor()
        
        # Check if already banned
        cur.execute('SELECT username FROM banned_users WHERE username = %s', (target_user,))
        if cur.fetchone():
            cur.close()
            conn.close()
            return jsonify({"error": "User is already muted"}), 400
        
        # Add to banned list
        cur.execute(
            '''INSERT INTO banned_users (username, banned_by, reason) 
               VALUES (%s, %s, %s)''',
            (target_user, moderator, reason)
        )
        
        conn.commit()
        cur.close()
        conn.close()
        
        # Add to in-memory set
        BANNED_USERS.add(target_user)
        
        return jsonify({
            "success": True,
            "message": f"{target_user} has been muted",
            "muted_by": moderator,
            "reason": reason
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/unmute', methods=['POST'])
def unmute_user():
    """Unmute/unban a user (Staff only)"""
    try:
        data = request.get_json()
        moderator = data.get('moderator')
        target_user = data.get('target_user')
        
        if not moderator or not is_staff(moderator):
            return jsonify({"error": "Unauthorized - Staff only"}), 403
        
        if not target_user:
            return jsonify({"error": "Missing target_user"}), 400
        
        conn = get_db_connection()
        if not conn:
            return jsonify({"error": "Database connection failed"}), 500
            
        cur = conn.cursor()
        
        # Remove from banned list
        cur.execute('DELETE FROM banned_users WHERE username = %s', (target_user,))
        deleted = cur.rowcount
        
        conn.commit()
        cur.close()
        conn.close()
        
        # Remove from in-memory set
        BANNED_USERS.discard(target_user)
        
        if deleted == 0:
            return jsonify({"error": "User was not muted"}), 400
        
        return jsonify({
            "success": True,
            "message": f"{target_user} has been unmuted",
            "unmuted_by": moderator
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/banned', methods=['GET'])
def get_banned_users():
    """Get list of banned users (Staff only)"""
    try:
        username = request.args.get('username')
        
        if not username or not is_staff(username):
            return jsonify({"error": "Unauthorized - Staff only"}), 403
        
        conn = get_db_connection()
        if not conn:
            return jsonify({"error": "Database connection failed"}), 500
            
        cur = conn.cursor()
        
        cur.execute('''
            SELECT username, banned_by, reason, banned_at 
            FROM banned_users 
            ORDER BY banned_at DESC
        ''')
        
        banned = cur.fetchall()
        
        banned_list = []
        for user in banned:
            banned_list.append({
                "username": user['username'],
                "banned_by": user['banned_by'],
                "reason": user['reason'],
                "banned_at": user['banned_at'].isoformat()
            })
        
        cur.close()
        conn.close()
        
        return jsonify({
            "success": True,
            "count": len(banned_list),
            "banned_users": banned_list
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/shutdown', methods=['POST'])
def shutdown():
    """Shutdown the server (Owners only)"""
    try:
        data = request.get_json()
        username = data.get('username')
        
        if not username or not is_owner(username):
            return jsonify({"error": "Unauthorized - Owners only"}), 403
        
        return jsonify({
            "success": True,
            "message": "Server shutdown initiated by " + username,
            "note": "On Render, the server will automatically restart"
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🚀 Starting Universal Roblox Chat Server v2.0...")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    if DATABASE_URL:
        print("📦 DATABASE_URL found!")
        print("🔗 Initializing database...")
        if init_database():
            print("✅ Database ready!")
        else:
            print("⚠️  Database initialization had issues")
            print("💡 Try visiting /setup endpoint to manually initialize")
    else:
        print("⚠️  WARNING: DATABASE_URL not set!")
        print("❌ App will not work without database!")
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    port = int(os.environ.get('PORT', 10000))
    print(f"🌐 Starting server on port {port}...")
    print(f"👑 Owners: foffasfieifro, Ya_shumi09")
    print(f"🛡️  Mods: shimul2222222")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    app.run(host='0.0.0.0', port=port)
