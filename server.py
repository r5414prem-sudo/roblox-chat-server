from flask import Flask, request, jsonify
from flask_cors import CORS
from datetime import datetime
import os
import requests
from collections import deque

app = Flask(__name__)
CORS(app)

DISCORD_WEBHOOK_URL = os.environ.get('DISCORD_WEBHOOK_URL')
# KEY_SYSTEM_API = "https://your-website.com/api/verify?key="

messages = deque(maxlen=200)
# Tracking active users (last seen within 30 seconds)
active_users = {} 

@app.route('/send', methods=['POST'])
def send_message():
    data = request.get_json()
    # auth_key = request.headers.get('Authorization')
    
    # Simple validation placeholder: 
    # if not verify_key_with_website(auth_key): return jsonify({"error": "Invalid Key"}), 401

    username = str(data.get('username', 'Unknown'))
    display_name = str(data.get('display_name', username))
    user_id = data.get('user_id', 0)
    message = str(data.get('message', ''))[:200]
    game = str(data.get('game', 'Unknown'))

    msg_obj = {
        "id": len(messages) + 1,
        "username": username,
        "display_name": display_name,
        "user_id": user_id,
        "message": message,
        "game": game,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }
    
    messages.append(msg_obj)
    active_users[username] = datetime.now()
    return jsonify({"success": True}), 201

@app.route('/messages', methods=['GET'])
def get_messages():
    since = request.args.get('since')
    viewer = request.args.get('username', 'Unknown')
    active_users[viewer] = datetime.now() # Mark viewer as active
    
    # Clean up old users
    now = datetime.now()
    to_delete = [u for u, t in active_users.items() if (now - t).total_seconds() > 30]
    for u in to_delete: del active_users[u]

    filtered = [msg for msg in messages if not since or msg['timestamp'] > since]
    
    return jsonify({
        "messages": filtered,
        "online_count": len(active_users)
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 10000)))
    
