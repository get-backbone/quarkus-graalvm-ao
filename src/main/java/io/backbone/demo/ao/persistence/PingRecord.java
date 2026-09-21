package io.backbone.demo.ao.persistence;

import io.backbone.kit.metrics.api.persistence.MetricsRecord;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Data;

@Data
@Entity
@Table(name = "ping_hits")
public class PingRecord implements MetricsRecord
{
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 128)
    private String caller;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
