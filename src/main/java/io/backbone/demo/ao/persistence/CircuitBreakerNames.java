package io.backbone.demo.ao.persistence;

/**
 * Named SmallRye circuit breaker constants for {@code @CircuitBreakerName} and
 * kit {@code @CircuitBreakerMetrics}. Included in AO reflect-config so the FQN
 * survives Advanced Obfuscation.
 */
public final class CircuitBreakerNames
{
    public static final String PING_SERVICE = "ao-demo-ping";

    private CircuitBreakerNames()
    {
    }
}
