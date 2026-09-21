package io.backbone.demo.ao;

import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

@Path("/ping")
@Produces(MediaType.APPLICATION_JSON)
public class PingResource
{
    private final PingService pingService;

    @Inject
    public PingResource(final PingService pingService)
    {
        this.pingService = pingService;
    }

    @GET
    public PingResponse ping(@QueryParam("caller") @DefaultValue("anonymous") final String caller)
    {
        final String safeCaller = (caller == null || caller.isBlank()) ? "anonymous" : caller;

        return pingService.ping(safeCaller);
    }
}
