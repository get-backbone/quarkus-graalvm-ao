package io.backbone.demo.ao.metrics;

import io.backbone.kit.metrics.api.domain.MetricsRecorder;
import io.backbone.kit.metrics.api.dto.MetricsResultIndicator;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.interceptor.InvocationContext;

@ApplicationScoped
public class PingMetricsRecorder implements MetricsRecorder
{
    private final MeterRegistry meterRegistry;

    @Inject
    public PingMetricsRecorder(final MeterRegistry meterRegistry)
    {
        this.meterRegistry = meterRegistry;
    }

    @Override
    public void recordMetrics(final InvocationContext context, final MetricsResultIndicator indicator)
    {
        final String status = indicator != null && indicator.success() ? "success" : "failure";
        Counter.builder("ao.demo.ping")
            .tag("operation", context.getMethod().getName())
            .tag("status", status)
            .register(meterRegistry)
            .increment();
    }

    @Override
    public void recordException(final InvocationContext context, final Exception exception)
    {
        Counter.builder("ao.demo.ping")
            .tag("operation", context.getMethod().getName())
            .tag("status", "exception")
            .tag("exception", exception.getClass().getSimpleName())
            .register(meterRegistry)
            .increment();
    }
}
