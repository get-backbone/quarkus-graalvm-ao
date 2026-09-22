package io.backbone.demo.ao;

import io.backbonehq.kit.metrics.api.dto.MetricsResultIndicator;
import java.io.Serializable;

/**
 * HTTP payload for {@code GET /ping}. Implements kit {@link MetricsResultIndicator}
 * so {@code @ServiceMetrics} can record success/failure. Also the Redis cache value type.
 */
public record PingResponse(boolean success, String status, Long rowId, String caller, String errorMessage) implements MetricsResultIndicator, Serializable
{
    public static PingResponse ok(final Long rowId, final String caller)
    {
        return new PingResponse(true, "ok", rowId, caller, null);
    }
}
