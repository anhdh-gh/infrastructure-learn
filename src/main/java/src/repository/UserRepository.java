package src.repository;

import jakarta.annotation.PostConstruct;
import org.springframework.stereotype.Repository;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import src.entity.User;

import java.util.List;
import java.util.stream.Collectors;

@Repository
public class UserRepository {

    private final DynamoDbEnhancedClient enhancedClient;
    private DynamoDbTable<User> userTable;

    public UserRepository(DynamoDbEnhancedClient enhancedClient) {
        this.enhancedClient = enhancedClient;
    }

    @PostConstruct
    public void init() {
        // Points to the exact "users" table managed by Terraform
        userTable = enhancedClient.table("users", TableSchema.fromBean(User.class));
    }

    public void save(User user) {
        userTable.putItem(user);
    }

    public User findById(String userId) {
        Key key = Key.builder().partitionValue(userId).build();
        return userTable.getItem(key);
    }

    public List<User> findAll() {
        return userTable.scan().items().stream().collect(Collectors.toList());
    }

    public void update(User user) {
        userTable.updateItem(user);
    }

    public void delete(String userId) {
        Key key = Key.builder().partitionValue(userId).build();
        userTable.deleteItem(key);
    }
}
