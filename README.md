# Quarkus + GraalVM Advanced Obfuscation

[![Quarkus](https://img.shields.io/badge/Quarkus-3.36.1-4695EB?logo=quarkus&logoColor=white)](https://quarkus.io/)
[![GraalVM](https://img.shields.io/badge/GraalVM-25-F2A900?logo=oracle&logoColor=white)](https://www.graalvm.org/jdk25/security-guide/native-image/obfuscation/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Demonstrates Quarkus + Oracle GraalVM 25 **Advanced Obfuscation** on a production-grade stack; not a hello-world that only adds `-H:AdvancedObfuscation`.

- Quarkus ArC CDI
- SmallRye Fault Tolerance 
- Redis cache
- Postgres/Hibernate 
- SmallRye Health + Micrometer/Prometheus
- [backbone-kit](https://github.com/get-backbone/backbone-kit) metrics, logging, throttle components

## Run

Needs JDK 25, Docker, [Task](https://taskfile.dev/), `jq`.

### JVM

```bash
task compose:up
task test
task dev                # optional — :8080
```

```bash
curl -s 'http://localhost:8080/ping?caller=demo' | jq
curl -s http://localhost:8080/q/health/ready | jq
```

### Advanced Obfuscation native image

```bash
task ao:build    # regenerates reflect-config, then container-build (~15–40m)
task ao:image
task ao:run
task ao:smoke
```

`ao:build` produces a Linux/glibc runner (required on macOS for the UBI image).

## Approach

AO renames reachable types by default. Quarkus FT, Narayana/Arjuna, and Vert.x still need original names for reflection,
CDI, and FT frames.

### `-H:Preserve` failed

Oracle docs point at `-H:Preserve=package=…`. On a Quarkus classpath that is a reachability hammer: it pulls optional /
unreachable types (Log4j bridges, Kotlin, MP Metrics, deployment classes) into the image, and the build dies with
`NoClassDefFoundError`. Narrower Preserve packages still did.

### Invert-target `reflect-config.json` worked

```json
{
  "name": "io.smallrye.faulttolerance.…",
  "condition": {
    "typeReachable": "io.smallrye.faulttolerance.…"
  }
}
```

AO keeps the name when the type is reachable, without force-including the rest of Quarkus. Generators under
`scripts/native/` (also run by `task ao:reflect` / `ao:build`):

1. `generate-ft-ao-reflect-config.sh` — SmallRye / Quarkus / MicroProfile Fault Tolerance
2. `generate-arjuna-ao-reflect-config.sh` — narrow Narayana/Arjuna suffixes (blanket `com.arjuna.**` OOM / times out)
3. `generate-redis-vertx-ao-reflect-config.sh` — Redis cache/client + Mutiny Vert.x

| Symptom                                                | Generator    |
|--------------------------------------------------------|--------------|
| SmallRye FT NPE / mangled FT frames                    | FT           |
| `NoSuchMethodException` on Arjuna `*EnvironmentBean`   | Arjuna       |
| `No bean found` for obfuscated Vert.x (e.g. `amo.amn`) | Redis/Vert.x |

### Other native notes

- Micrometer Vert.x binder NPE under AO → `quarkus.micrometer.binder.vertx.enabled=false`
- `org.fusesource.jansi` → `--initialize-at-run-time` (merged with AO flags in `Taskfile.yml` `ao:build`; CLI
  `additional-build-args` replaces `application.properties` for that key)

### Takeaways

1. Rename-only carve-outs are awkward today: `-H:Preserve` is reachability, not "keep these names."
2. Large framework-wide reflect Preserve lists can OOM AO compile (seen with Arjuna).
3. AO is Oracle GraalVM only; Quarkus native guides are Mandrel-first, so Quarkus + AO is under-documented.
