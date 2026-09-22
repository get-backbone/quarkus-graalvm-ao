package io.backbone.demo.ao;

import io.backbone.demo.ao.metrics.PingMetricsRecorder;
import io.backbone.demo.ao.persistence.CircuitBreakerNames;
import io.backbone.demo.ao.persistence.PingRecord;
import io.backbone.demo.ao.persistence.PingRepository;
import io.backbonehq.kit.logging.api.LogMethodEntry;
import io.backbonehq.kit.metrics.api.domain.ServiceMetrics;
import io.backbonehq.kit.metrics.api.faulttolerance.CircuitBreakerMetrics;
import io.quarkus.cache.CacheResult;
import io.smallrye.faulttolerance.api.CircuitBreakerName;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.microprofile.faulttolerance.CircuitBreaker;
import org.eclipse.microprofile.faulttolerance.Retry;
import org.eclipse.microprofile.faulttolerance.Timeout;

@ApplicationScoped
@CircuitBreakerMetrics
public class PingService
{
    private final PingRepository pingRepository;

    @Inject
    public PingService(final PingRepository pingRepository)
    {
        this.pingRepository = pingRepository;
    }

    @ServiceMetrics(PingMetricsRecorder.class)
    @Retry(maxRetries = 1)
    @Timeout(2000)
    @CircuitBreaker(requestVolumeThreshold = 8, failureRatio = 0.5, delay = 1000)
    @CircuitBreakerName(CircuitBreakerNames.PING_SERVICE)
    @CacheResult(cacheName = "ping")
    @LogMethodEntry(message = "for caller: %s")
    public PingResponse ping(final String caller)
    {
        final PingRecord saved = pingRepository.save(caller);
        return PingResponse.ok(saved.getId(), caller);
    }
}
