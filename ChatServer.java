package com.roblox.chat;

import com.sun.net.httpserver.*;
import com.google.gson.*;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.time.*;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.Collectors;

/**
 * Universal Roblox Cross-Game Chat Server
 * High-performance Java backend with thread-safe operations
 * 
 * @version 2.0.0
 * @author Universal Chat Team
 */
public class ChatServer {
    
    // Configuration
    private static final int PORT = Integer.parseInt(System.getenv().getOrDefault("PORT", "10000"));
    private static final int MAX_MESSAGES = 200;
    private static final int MAX_MESSAGE_LENGTH = 500;
    private static final int MAX_USERNAME_LENGTH = 50;
    private static final int MAX_GAME_LENGTH = 100;
    
    // Thread-safe storage
    private static final ConcurrentLinkedDeque<Message> messages = new ConcurrentLinkedDeque<>();
    private static final ConcurrentHashMap<String, UserInfo> activeUsers = new ConcurrentHashMap<>();
    private static final AtomicInteger totalMessages = new AtomicInteger(0);
    private static final LocalDateTime serverStartTime = LocalDateTime.now();
    
    // JSON serialization
    private static final Gson gson = new GsonBuilder()
            .setPrettyPrinting()
            .setDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
            .create();
    
    // Cleanup scheduler
    private static final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
    
    /**
     * Message data model
     */
    static class Message {
        int id;
        String username;
        String message;
        String game;
        String timestamp;
        
        Message(int id, String username, String message, String game) {
            this.id = id;
            this.username = username;
            this.message = message;
            this.game = game;
            this.timestamp = ZonedDateTime.now(ZoneOffset.UTC)
                    .format(DateTimeFormatter.ISO_INSTANT);
        }
    }
    
    /**
     * User info tracker
     */
    static class UserInfo {
        String username;
        String lastGame;
        LocalDateTime lastSeen;
        int messageCount;
        
        UserInfo(String username, String game) {
            this.username = username;
            this.lastGame = game;
            this.lastSeen = LocalDateTime.now();
            this.messageCount = 1;
        }
        
        void updateActivity(String game) {
            this.lastGame = game;
            this.lastSeen = LocalDateTime.now();
            this.messageCount++;
        }
    }
    
    /**
     * Main server entry point
     */
    public static void main(String[] args) throws IOException {
        // Create HTTP server
        HttpServer server = HttpServer.create(new InetSocketAddress(PORT), 0);
        
        // Configure thread pool
        ExecutorService executor = Executors.newFixedThreadPool(10);
        server.setExecutor(executor);
        
        // Register endpoints
        server.createContext("/", new HomeHandler());
        server.createContext("/send", new SendMessageHandler());
        server.createContext("/messages", new GetMessagesHandler());
        server.createContext("/stats", new StatsHandler());
        server.createContext("/clear", new ClearHandler());
        server.createContext("/health", new HealthHandler());
        
        // Start cleanup scheduler (every 5 minutes)
        scheduler.scheduleAtFixedRate(() -> cleanupInactiveUsers(), 5, 5, TimeUnit.MINUTES);
        
        // Start server
        server.start();
        
        // Print startup banner
        printBanner();
        System.out.println("🚀 Server started successfully on port " + PORT);
        System.out.println("🌐 Access at: http://localhost:" + PORT);
        System.out.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
    }
    
    /**
     * Print aesthetic startup banner
     */
    private static void printBanner() {
        System.out.println("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        System.out.println("  🌐 UNIVERSAL ROBLOX CHAT SERVER");
        System.out.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        System.out.println("  Version: 2.0.0");
        System.out.println("  Language: Java " + System.getProperty("java.version"));
        System.out.println("  Storage: In-Memory (Thread-Safe)");
        System.out.println("  Max Messages: " + MAX_MESSAGES);
        System.out.println("  CORS: Enabled");
        System.out.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    }
    
    /**
     * Home endpoint - Server info
     */
    static class HomeHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            setCorsHeaders(exchange);
            
            if ("OPTIONS".equals(exchange.getRequestMethod())) {
                exchange.sendResponseHeaders(204, -1);
                return;
            }
            
            Duration uptime = Duration.between(serverStartTime, LocalDateTime.now());
            
            Map<String, Object> response = new HashMap<>();
            response.put("status", "online");
            response.put("service", "Universal Roblox Chat");
            response.put("version", "2.0.0");
            response.put("language", "Java");
            response.put("uptime_seconds", uptime.getSeconds());
            response.put("messages_stored", messages.size());
            response.put("active_users", activeUsers.size());
            response.put("total_messages", totalMessages.get());
            
            sendJsonResponse(exchange, 200, response);
        }
    }
    
    /**
     * Send message endpoint
     */
    static class SendMessageHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            setCorsHeaders(exchange);
            
            if ("OPTIONS".equals(exchange.getRequestMethod())) {
                exchange.sendResponseHeaders(204, -1);
                return;
            }
            
            if (!"POST".equals(exchange.getRequestMethod())) {
                sendError(exchange, 405, "Method not allowed");
                return;
            }
            
            try {
                // Read request body
                String body = new BufferedReader(new InputStreamReader(exchange.getRequestBody()))
                        .lines().collect(Collectors.joining("\n"));
                
                JsonObject json = gson.fromJson(body, JsonObject.class);
                
                // Validate input
                if (!json.has("username") || !json.has("message")) {
                    sendError(exchange, 400, "Missing username or message");
                    return;
                }
                
                String username = sanitize(json.get("username").getAsString(), MAX_USERNAME_LENGTH);
                String messageText = sanitize(json.get("message").getAsString(), MAX_MESSAGE_LENGTH);
                String game = json.has("game") ? 
                        sanitize(json.get("game").getAsString(), MAX_GAME_LENGTH) : "Unknown";
                
                if (username.isEmpty() || messageText.isEmpty()) {
                    sendError(exchange, 400, "Username and message cannot be empty");
                    return;
                }
                
                // Create message
                int messageId = totalMessages.incrementAndGet();
                Message msg = new Message(messageId, username, messageText, game);
                
                // Store message
                messages.addLast(msg);
                if (messages.size() > MAX_MESSAGES) {
                    messages.removeFirst();
                }
                
                // Update user info
                activeUsers.compute(username, (k, v) -> {
                    if (v == null) {
                        return new UserInfo(username, game);
                    } else {
                        v.updateActivity(game);
                        return v;
                    }
                });
                
                // Log message
                System.out.println(String.format("📨 [%s] %s: %s", game, username, messageText));
                
                // Send response
                Map<String, Object> response = new HashMap<>();
                response.put("success", true);
                response.put("message", "Message sent");
                response.put("data", msg);
                
                sendJsonResponse(exchange, 201, response);
                
            } catch (Exception e) {
                e.printStackTrace();
                sendError(exchange, 500, "Internal server error: " + e.getMessage());
            }
        }
    }
    
    /**
     * Get messages endpoint
     */
    static class GetMessagesHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            setCorsHeaders(exchange);
            
            if ("OPTIONS".equals(exchange.getRequestMethod())) {
                exchange.sendResponseHeaders(204, -1);
                return;
            }
            
            try {
                // Parse query parameters
                Map<String, String> params = queryToMap(exchange.getRequestURI().getQuery());
                String since = params.get("since");
                int limit = Math.min(
                    Integer.parseInt(params.getOrDefault("limit", "20")), 
                    MAX_MESSAGES
                );
                
                // Filter messages
                List<Message> filtered = new ArrayList<>(messages);
                
                if (since != null && !since.isEmpty()) {
                    filtered = filtered.stream()
                            .filter(m -> m.timestamp.compareTo(since) > 0)
                            .collect(Collectors.toList());
                }
                
                // Get last N messages
                if (filtered.size() > limit) {
                    filtered = filtered.subList(filtered.size() - limit, filtered.size());
                }
                
                // Send response
                Map<String, Object> response = new HashMap<>();
                response.put("success", true);
                response.put("count", filtered.size());
                response.put("messages", filtered);
                
                sendJsonResponse(exchange, 200, response);
                
            } catch (Exception e) {
                e.printStackTrace();
                sendError(exchange, 500, "Internal server error: " + e.getMessage());
            }
        }
    }
    
    /**
     * Statistics endpoint
     */
    static class StatsHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            setCorsHeaders(exchange);
            
            if ("OPTIONS".equals(exchange.getRequestMethod())) {
                exchange.sendResponseHeaders(204, -1);
                return;
            }
            
            Duration uptime = Duration.between(serverStartTime, LocalDateTime.now());
            
            Map<String, Object> response = new HashMap<>();
            response.put("total_messages", totalMessages.get());
            response.put("unique_users", activeUsers.size());
            response.put("messages_in_memory", messages.size());
            response.put("uptime_hours", String.format("%.2f", uptime.toHours() + uptime.toMinutesPart() / 60.0));
            response.put("server_start", serverStartTime.toString());
            
            sendJsonResponse(exchange, 200, response);
        }
    }
    
    /**
     * Clear messages endpoint
     */
    static class ClearHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            setCorsHeaders(exchange);
            
            if ("OPTIONS".equals(exchange.getRequestMethod())) {
                exchange.sendResponseHeaders(204, -1);
                return;
            }
            
            if (!"POST".equals(exchange.getRequestMethod())) {
                sendError(exchange, 405, "Method not allowed");
                return;
            }
            
            int deleted = messages.size();
            messages.clear();
            
            System.out.println("🗑️  Cleared " + deleted + " messages");
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("deleted", deleted);
            response.put("message", "All messages cleared");
            
            sendJsonResponse(exchange, 200, response);
        }
    }
    
    /**
     * Health check endpoint
     */
    static class HealthHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            setCorsHeaders(exchange);
            
            if ("OPTIONS".equals(exchange.getRequestMethod())) {
                exchange.sendResponseHeaders(204, -1);
                return;
            }
            
            Map<String, Object> response = new HashMap<>();
            response.put("status", "healthy");
            response.put("timestamp", ZonedDateTime.now(ZoneOffset.UTC).toString());
            
            sendJsonResponse(exchange, 200, response);
        }
    }
    
    // ============ UTILITY METHODS ============
    
    /**
     * Set CORS headers
     */
    private static void setCorsHeaders(HttpExchange exchange) {
        Headers headers = exchange.getResponseHeaders();
        headers.add("Access-Control-Allow-Origin", "*");
        headers.add("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
        headers.add("Access-Control-Allow-Headers", "Content-Type");
    }
    
    /**
     * Send JSON response
     */
    private static void sendJsonResponse(HttpExchange exchange, int statusCode, Object data) 
            throws IOException {
        String json = gson.toJson(data);
        byte[] bytes = json.getBytes(StandardCharsets.UTF_8);
        
        exchange.getResponseHeaders().add("Content-Type", "application/json; charset=UTF-8");
        exchange.sendResponseHeaders(statusCode, bytes.length);
        
        try (OutputStream os = exchange.getResponseBody()) {
            os.write(bytes);
        }
    }
    
    /**
     * Send error response
     */
    private static void sendError(HttpExchange exchange, int statusCode, String message) 
            throws IOException {
        Map<String, String> error = new HashMap<>();
        error.put("error", message);
        sendJsonResponse(exchange, statusCode, error);
    }
    
    /**
     * Sanitize and limit string length
     */
    private static String sanitize(String input, int maxLength) {
        if (input == null) return "";
        input = input.trim();
        if (input.length() > maxLength) {
            input = input.substring(0, maxLength);
        }
        return input;
    }
    
    /**
     * Parse query string to map
     */
    private static Map<String, String> queryToMap(String query) {
        Map<String, String> result = new HashMap<>();
        if (query == null || query.isEmpty()) return result;
        
        for (String param : query.split("&")) {
            String[] pair = param.split("=");
            if (pair.length > 1) {
                try {
                    result.put(
                        URLDecoder.decode(pair[0], StandardCharsets.UTF_8),
                        URLDecoder.decode(pair[1], StandardCharsets.UTF_8)
                    );
                } catch (Exception e) {
                    // Skip invalid parameters
                }
            }
        }
        return result;
    }
    
    /**
     * Clean up inactive users (not seen in 10 minutes)
     */
    private static void cleanupInactiveUsers() {
        LocalDateTime cutoff = LocalDateTime.now().minusMinutes(10);
        activeUsers.entrySet().removeIf(entry -> entry.getValue().lastSeen.isBefore(cutoff));
        System.out.println("🧹 Cleaned up inactive users. Active: " + activeUsers.size());
    }
                             }
