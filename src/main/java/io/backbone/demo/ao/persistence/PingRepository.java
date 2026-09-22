package io.backbone.demo.ao.persistence;

import io.backbonehq.kit.metrics.api.persistence.DatabaseMetrics;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;

@ApplicationScoped
public class PingRepository
{
    private final EntityManager entityManager;

    @Inject
    public PingRepository(final EntityManager entityManager)
    {
        this.entityManager = entityManager;
    }

    @Transactional
    @DatabaseMetrics(entity = PingRecord.class)
    public PingRecord save(final String caller)
    {
        final PingRecord record = new PingRecord();
        record.setCaller(caller);

        entityManager.persist(record);
        entityManager.flush();

        return record;
    }
}
