package src.controller;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.servlet.view.RedirectView;

@Controller
public class DynamoDbViewController {

    @GetMapping("/dynamodb")
    public RedirectView getDynamoDbPage() {
        return new RedirectView("/dynamodb.html");
    }
}
