from flask import Flask, request, jsonify
from flask_cors import CORS
from datetime import datetime
import os
import requests
from collections import deque

app = Flask(__name__)
CORS(app)

# 🎮 DISCORD WEBHOOK (from environment variable - NO hardcoded URL!)
DISCORD_WEBHOOK_URL = os.environ.get('DISCORD_WEBHOOK_URL')

# 👑 RANK SYSTEM
RANKS = {
    "foffasfieifro": {"rank": "Owner", "emoji": "👑", "color": "#FFD700", "level": 3, "discord_color": 16766720},
    "Ya_shumi09": {"rank": "Owner", "emoji": "👑", "color": "#FFD700", "level": 3, "discord_color": 16766720},
    "shimul2222222": {"rank": "Mod", "emoji": "🛡️", "color": "#4ECDC4", "level": 2, "discord_color": 5164228},
}

DEFAULT_RANK = {"rank": "Member", "emoji": "👤", "color": "#CCCCCC", "level": 0, "discord_color": 13421772}

# 💾 IN-MEMORY STORAGE
messages = deque(maxlen=200)  # Keep last 200 messages
banned_users = {}  # {username: {banned_by, reason, timestamp}}
stats = {
    "total_messages": 0,
    "unique_users": set(),
    "server_start_time": datetime.now()
}

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

def send_to_discord(content=None, embed=None):
    """Send message to Discord webhook"""
    if not DISCORD_WEBHOOK_URL:
        print("⚠️ Discord webhook not configured")
        return False
    
    try:
        data = {}
        if content:
            data['content'] = content
        if embed:
            data['embeds'] = [embed]
        
        response = requests.post(DISCORD_WEBHOOK_URL, json=data, timeout=5)
        return response.status_code == 204
    except Exception as e:
        print(f"❌ Discord webhook error: {e}")
        return False

def create_message_embed(username, message, game, rank_info):
    """Create Discord embed for chat message"""
    return {
        "title": f"{rank_info['emoji']} {rank_info['rank']}: {username}",
        "description": message,
        "color": rank_info.get('discord_color', 13421772),
        "fields": [
            {"name": "Game", "value": game, "inline": True},
            {"name": "Time", "value": datetime.now().strftime("%H:%M:%S"), "inline": True}
        ],
        "footer": {"text": "Universal Roblox Chat"}
    }

def create_mod_embed(action, moderator, details, color=16744192):
    """Create Discord embed for moderation action"""
    return {
        "title": f"🛡️ Moderation Action: {action}",
        "description": details,
        "color": color,
        "fields": [
            {"name": "Moderator", "value": moderator, "inline": True},
            {"name": "Time", "value": datetime.now().strftime("%H:%M:%S %d/%m/%Y"), "inline": True}
        ],
        "footer": {"text": "Mod Log"}
    }

@app.route('/', methods=['GET'])
def home():
    uptime = datetime.now() - stats["server_start_time"]
    return jsonify({
        "status": "online",
        "service": "Universal Roblox Chat",
        "storage": "In-Memory (No Database)",
        "features": ["ranks", "discord_logging", "moderation"],
        "version": "3.0",
        "uptime_seconds": int(uptime.total_seconds()),
        "messages_stored": len(messages),
        "discord_webhook": "Connected" if DISCORD_WEBHOOK_URL else "Not configured"
    })

@app.route('/send', methods=['POST'])
def send_message():
    """Send a message"""
    try:
        data = request.get_json()
        
        if not data or 'username' not in data or 'message' not in data:
            return jsonify({"error": "Missing username or message"}), 400
        
        username = str(data['username'])[:50]
        message = str(data['message'])[:500]
        game = str(data.get('game', 'Unknown'))[:100]
        
        # Check if user is banned
        if username in banned_users:
            return jsonify({"error": "You are muted from the chat"}), 403
        
        # Get user rank
        rank_info = get_user_rank(username)
        
        # Create message object
        msg_obj = {
            "id": stats["total_messages"] + 1,
            "username": username,
            "message": message,
            "game": game,
            "rank": rank_info['rank'],
            "rank_emoji": rank_info['emoji'],
            "rank_color": rank_info['color'],
            "timestamp": datetime.now().isoformat()
        }
        
        # Save to memory
        messages.append(msg_obj)
        stats["total_messages"] += 1
        stats["unique_users"].add(username)
        
        # Send to Discord
        embed = create_message_embed(username, message, game, rank_info)
        send_to_discord(embed=embed)
        
        return jsonify({
            "success": True,
            "message": "Message sent",
            "data": msg_obj
        }), 201
        
    except Exception as e:
        print(f"❌ Send error: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/messages', methods=['GET'])
def get_messages():
    """Get recent messages"""
    try:
        since = request.args.get('since')
        limit = request.args.get('limit', 20, type=int)
        limit = min(limit, 200)
        
        # Filter messages
        if since:
            filtered = [msg for msg in messages if msg['timestamp'] > since]
        else:
            filtered = list(messages)
        
        # Get last N messages
        recent = filtered[-limit:] if len(filtered) > limit else filtered
        
        return jsonify({
            "success": True,
            "count": len(recent),
            "messages": recent
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
    uptime = datetime.now() - stats["server_start_time"]
    return jsonify({
        "total_messages": stats["total_messages"],
        "unique_users": len(stats["unique_users"]),
        "messages_in_memory": len(messages),
        "banned_users": len(banned_users),
        "uptime_hours": round(uptime.total_seconds() / 3600, 2),
        "server_start": stats["server_start_time"].isoformat()
    })

# ============ MODERATION ENDPOINTS ============

@app.route('/clear', methods=['POST'])
def clear_messages():
    """Clear all messages (Staff only)"""
    try:
        data = request.get_json()
        username = data.get('username')
        
        if not username or not is_staff(username):
            return jsonify({"error": "Unauthorized - Staff only"}), 403
        
        deleted = len(messages)
        messages.clear()
        
        # Log to Discord
        embed = create_mod_embed(
            "CLEAR",
            username,
            f"Cleared {deleted} messages from chat",
            16744192  # Orange
        )
        send_to_discord(embed=embed)
        
        return jsonify({
            "success": True,
            "deleted": deleted,
            "cleared_by": username
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/mute', methods=['POST'])
def mute_user():
    """Mute a user (Staff only)"""
    try:
        data = request.get_json()
        moderator = data.get('moderator')
        target_user = data.get('target_user')
        reason = data.get('reason', 'No reason provided')
        
        if not moderator or not is_staff(moderator):
            return jsonify({"error": "Unauthorized - Staff only"}), 403
        
        if not target_user:
            return jsonify({"error": "Missing target_user"}), 400
        
        if is_staff(target_user):
            return jsonify({"error": "Cannot mute staff members"}), 400
        
        if target_user in banned_users:
            return jsonify({"error": "User is already muted"}), 400
        
        # Add to banned list
        banned_users[target_user] = {
            "banned_by": moderator,
            "reason": reason,
            "timestamp": datetime.now().isoformat()
        }
        
        # Log to Discord
        embed = create_mod_embed(
            "MUTE",
            moderator,
            f"**Target:** {target_user}\n**Reason:** {reason}",
            15158332  # Red
        )
        send_to_discord(embed=embed)
        
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
    """Unmute a user (Staff only)"""
    try:
        data = request.get_json()
        moderator = data.get('moderator')
        target_user = data.get('target_user')
        
        if not moderator or not is_staff(moderator):
            return jsonify({"error": "Unauthorized - Staff only"}), 403
        
        if not target_user:
            return jsonify({"error": "Missing target_user"}), 400
        
        if target_user not in banned_users:
            return jsonify({"error": "User was not muted"}), 400
        
        # Remove from banned list
        del banned_users[target_user]
        
        # Log to Discord
        embed = create_mod_embed(
            "UNMUTE",
            moderator,
            f"**Target:** {target_user}\nUser has been unmuted",
            3066993  # Green
        )
        send_to_discord(embed=embed)
        
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
        
        banned_list = []
        for user, info in banned_users.items():
            banned_list.append({
                "username": user,
                "banned_by": info['banned_by'],
                "reason": info['reason'],
                "banned_at": info['timestamp']
            })
        
        return jsonify({
            "success": True,
            "count": len(banned_list),
            "banned_users": banned_list
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/shutdown', methods=['POST'])
def shutdown():
    """Shutdown notification (Owners only)"""
    try:
        data = request.get_json()
        username = data.get('username')
        
        if not username or not is_owner(username):
            return jsonify({"error": "Unauthorized - Owners only"}), 403
        
        # Log to Discord
        send_to_discord(content=f"🔴 **Server shutdown requested by {username}**")
        
        return jsonify({
            "success": True,
            "message": f"Shutdown notification sent by {username}"
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🚀 Universal Roblox Chat Server v3.0")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("💾 Storage: In-Memory (No Database)")
    
    if DISCORD_WEBHOOK_URL:
        print("🎮 Discord Webhook: ✅ Connected")
    else:
        print("🎮 Discord Webhook: ❌ Not Set (Set DISCORD_WEBHOOK_URL env variable)")
    
    print(f"👑 Owners: foffasfieifro, Ya_shumi09")
    print(f"🛡️  Mods: shimul2222222")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    # Send startup notification to Discord
    if DISCORD_WEBHOOK_URL:
        send_to_discord(content="🟢 **Universal Roblox Chat Server Started!**")
    
    port = int(os.environ.get('PORT', 10000))
    print(f"🌐 Server running on port {port}")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    app.run(host='0.0.0.0', port=port)
