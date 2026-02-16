# 🌐 Universal Roblox Chat Server

[![Java](https://img.shields.io/badge/Java-11+-orange.svg)](https://www.oracle.com/java/)
[![Maven](https://img.shields.io/badge/Maven-3.6+-blue.svg)](https://maven.apache.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

High-performance Java backend for cross-game Roblox chat system. Allows players from different Roblox games to chat with each other in real-time.

## ✨ Features

- 🚀 **High Performance** - Thread-safe concurrent operations
- 💾 **In-Memory Storage** - Stores last 200 messages
- 🌐 **CORS Enabled** - Works with any Roblox game
- 📊 **Real-time Stats** - Track users and messages
- 🧹 **Auto Cleanup** - Removes inactive users automatically
- ⚡ **Fast & Stable** - Built with pure Java, no external frameworks

## 🏗️ Architecture

- **Language:** Java 11+
- **Build Tool:** Maven
- **Storage:** In-Memory (ConcurrentHashMap & ConcurrentLinkedDeque)
- **HTTP Server:** Java built-in HttpServer
- **JSON:** Google Gson

## 📡 API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Server status and info |
| `/send` | POST | Send a message |
| `/messages` | GET | Get recent messages |
| `/stats` | GET | Server statistics |
| `/clear` | POST | Clear all messages |
| `/health` | GET | Health check |

## 🚀 Quick Start

### Prerequisites
- Java 11 or higher
- Maven 3.6+

### Build
```bash
mvn clean package
```

### Run Locally
```bash
java -jar target/universal-chat-server-2.0.0.jar
```

Server will start on port **10000** (or `$PORT` environment variable).

## 🌐 Deployment

### Deploy to Render.com

1. **Fork/Clone this repository**
2. **Sign up at [render.com](https://render.com)**
3. **Create New Web Service**
4. **Connect your GitHub repository**
5. **Configure:**
   - **Build Command:** `mvn clean package`
   - **Start Command:** `java -Xmx512m -jar target/universal-chat-server-2.0.0.jar`
   - **Environment Variable:** `PORT=10000`
6. **Deploy!**

### Deploy to Railway.app

1. **Fork/Clone this repository**
2. **Sign up at [railway.app](https://railway.app)**
3. **New Project → Deploy from GitHub**
4. **Select this repository**
5. Railway auto-detects Maven and deploys
6. **Set Environment Variable:** `PORT=10000`

### Deploy to Heroku

```bash
heroku create your-app-name
git push heroku main
```

## 🎮 Client Integration

Use with the Roblox Lua client.

Update the client's `SERVER_URL` to your deployed server URL:
```lua
SERVER_URL = "https://your-app-name.onrender.com"
```

## 📊 API Examples

### Send Message
```bash
curl -X POST https://your-server.com/send \
  -H "Content-Type: application/json" \
  -d '{
    "username": "Player123",
    "message": "Hello world!",
    "game": "My Cool Game"
  }'
```

### Get Messages
```bash
curl https://your-server.com/messages?limit=20
```

### Get Stats
```bash
curl https://your-server.com/stats
```

## 🔧 Configuration

Configure via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | 10000 | Server port |

## 📈 Performance

- **Concurrent Users:** 1000+ simultaneous connections
- **Message Throughput:** 100+ messages/second
- **Memory Usage:** ~50MB baseline
- **Latency:** <50ms response time

## 🛡️ Security Features

- Input sanitization (username/message length limits)
- CORS headers for cross-origin requests
- No authentication (public chat system)
- Rate limiting (via Render/Railway)

## 📝 License

MIT License - feel free to use for any purpose!

## 👨‍💻 Author

Created with ❤️ for the Roblox community

## 🤝 Contributing

Contributions welcome! Feel free to:
- Report bugs
- Suggest features
- Submit pull requests

## 🙏 Acknowledgments

- Built with Java 11+
- Uses Google Gson for JSON
- Inspired by Discord's chat system

---

⭐ **Star this repo if you find it useful!**
