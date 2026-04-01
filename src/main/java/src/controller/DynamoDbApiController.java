package src.controller;

import org.springframework.web.bind.annotation.*;
import src.entity.User;
import src.repository.UserRepository;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/dynamodb")
public class DynamoDbApiController {

    private final UserRepository userRepository;

    public DynamoDbApiController(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @GetMapping
    public List<User> getAllUsers() {
        return userRepository.findAll();
    }

    @GetMapping("/{userId}")
    public User getUser(@PathVariable String userId) {
        return userRepository.findById(userId);
    }

    @PostMapping
    public User createUser(@RequestBody User user) {
        if (user.getUserId() == null || user.getUserId().isEmpty()) {
            user.setUserId(UUID.randomUUID().toString());
        }
        userRepository.save(user);
        return user;
    }

    @PutMapping("/{userId}")
    public User updateUser(@PathVariable String userId, @RequestBody User user) {
        user.setUserId(userId);
        userRepository.update(user);
        return user;
    }

    @DeleteMapping("/{userId}")
    public void deleteUser(@PathVariable String userId) {
        userRepository.delete(userId);
    }
}
