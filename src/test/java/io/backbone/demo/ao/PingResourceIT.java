package io.backbone.demo.ao;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.notNullValue;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

@QuarkusTest
class PingResourceIT
{
    @Test
    void pingReturnsOkWithKitCorrelationId()
    {
        given()
            .queryParam("caller", "it")
            .when()
            .get("/ping")
            .then()
            .statusCode(200)
            .header("X-Correlation-Id", notNullValue())
            .body("success", equalTo(true))
            .body("status", equalTo("ok"))
            .body("caller", equalTo("it"))
            .body("rowId", notNullValue());
    }

    @Test
    void readinessIsUp()
    {
        given()
            .when()
            .get("/q/health/ready")
            .then()
            .statusCode(200)
            .body("status", equalTo("UP"));
    }
}
