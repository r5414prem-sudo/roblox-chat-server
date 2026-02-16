package com.roblox.universalchat;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.*;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

@SpringBootApplication
@RestController
@EnableScheduling
@CrossOrigin(origins = "*") // Allow Roblox to connect
public class ChatApplication {

    // --- In-Memory Storage ---
    // Thread-safe list for messages
    private final List<Map<String, Object>> messages = new CopyOnWriteArrayList<>();
    // Thread-safe map for online users: <Username, LastSeenTime>
    private final Map<String, LocalDateTime> onlineUsers = new ConcurrentHashMap<>();

    public static void main(String[] args) {
        SpringApplication.run(ChatApplication.class, args);
    }

    // --- Endpoints ---

    @GetMapping("/")
    public Map<String, String> status() {
        return Map.of(
            "status", "online",
            "server", "Java Spring Boot",
            "version", "2.0-Aesthetic"
        );
    }

    @PostMapping("/send")
    public Map<String, Object> sendMessage(@RequestBody Map<String, Object> payload) {
        // validate
        if (!payload.containsKey("message") || !payload.containsKey("username")) {
            return Map.of("error", "Missing fields");
        }

        // Clean inputs
        String username = String.valueOf(payload.get("username"));
        String displayName = (String) payload.getOrDefault("displayName", username);
        String msgContent = String.valueOf(payload.get("message"));
        String game = (String) payload.getOrDefault("game", "Unknown");
        String userId = String.valueOf(payload.getOrDefault("userId", "1"));
        String time = (String) payload.getOrDefault("time", "00:00");

        // Construct Message Object
        Map<String, Object> msg = new HashMap<>();
        msg.put("id", UUID.randomUUID().toString());
        msg.put("username", username);
        msg.put("displayName", displayName);
        msg.put("userId", userId);
        msg.put("message", msgContent.substring(0, Math.min(msgContent.length(), 200))); // Limit 200 chars
        msg.put("game", game);
        msg.put("time", time);
        msg.put("timestamp", LocalDateTime.now().toString());

        // Add to storage (Keep only last 50)
        messages.add(msg);
        if (messages.size() > 50) {
            messages.remove(0);
        }

        // Update sender online status
        onlineUsers.put(username, LocalDateTime.now());

        return Map.of("success", true);
    }

    @GetMapping("/messages")
    public Map<String, Object> getMessages(
            @RequestParam(required = false) String since,
            @RequestParam(required = false) String user) {

        // Heartbeat for the fetching user
        if (user != null && !user.isEmpty()) {
            onlineUsers.put(user, LocalDateTime.now());
        }

        // Filter messages
        List<Map<String, Object>> recentMessages = new ArrayList<>();
        if (since != null) {
            for (Map<String, Object> m : messages) {
                String ts = (String) m.get("timestamp");
                if (ts.compareTo(since) > 0) {
                    recentMessages.add(m);
                }
            }
        } else {
            // If no 'since', give last 20
            int start = Math.max(0, messages.size() - 20);
            recentMessages.addAll(messages.subList(start, messages.size()));
        }

        return Map.of(
            "messages", recentMessages,
            "onlineCount", onlineUsers.size()
        );
    }

    // --- Background Tasks ---

    // Clean up offline users every 5 seconds
    @Scheduled(fixedRate = 5000)
    public void cleanupUsers() {
        LocalDateTime cutoff = LocalDateTime.now().minusSeconds(15);
        onlineUsers.entrySet().removeIf(entry -> entry.getValue().isBefore(cutoff));
    }
    }
