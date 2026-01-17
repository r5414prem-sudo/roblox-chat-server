from flask import Flask, request, jsonify
from flask_cors import CORS
from datetime import datetime
import os

app = Flask(__name__)
CORS(app)

messages = []
MAX_MESSAGES = 100

@app.route('/', methods=['GET'])
def home():
    return jsonify({"status": "online", "service": "Universal Roblox Chat"})

@app.route('/send', methods=['POST'])
def send_message():
    try:
        data = request.get_json()
        username = str(data['username'])[:50]
        message = str(data['message'])[:500]
        game = str(data.get('game', 'Unknown'))[:100]
        
        new_message = {
            "id": len(messages) + 1,
            "username": username,
            "message": message,
            "game": game,
            "timestamp": datetime.now().isoformat()
        }
        
        messages.append(new_message)
        if len(messages) > MAX_MESSAGES:
            messages.pop(0)
        
        return jsonify({"success": True, "data": new_message}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/messages', methods=['GET'])
def get_messages():
    try:
        since = request.args.get('since')
        if since:
            since_dt = datetime.fromisoformat(since)
            filtered = [m for m in messages if datetime.fromisoformat(m['timestamp']) > since_dt]
            return jsonify({"success": True, "messages": filtered})
        else:
            recent = messages[-20:] if len(messages) > 20 else messages
            return jsonify({"success": True, "messages": recent})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 10000))
    app.run(host='0.0.0.0', port=port
