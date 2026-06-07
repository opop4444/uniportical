# Uniportical

**Uni**Fi + **portical** — declarative, label-driven port forwarding for Docker,
backed by the **UniFi controller API**. (A *portico* is a gateway/entrance,
which is exactly what a port forward is.)

Label your containers with the ports they need; Uniportical reconciles matching
**static UniFi port-forward rules**.

📦 **Image:** [`opop4444/uniportical`](https://hub.docker.com/r/opop4444/uniportical) on Docker Hub — `docker pull opop4444/uniportical`

## Why not UPnP / portical?

On UniFi a UPnP request creates the NAT mapping but the zone-based firewall
never grants the matching WAN-in allow — so the port is mapped yet stays closed
(verified: the IGD shows the mapping `enabled=1`, traffic is still dropped). A
**static port forward created via the UniFi API gets the firewall allow
automatically**, so it actually works. Uniportical keeps portical's model and
swaps the broken backend for one that works.

## Auth: a local UniFi API key

Uniportical authenticates with `X-API-KEY` and nothing else — so you need a
**local** UniFi API key. A Site-Manager (cloud) key will **not** work. To create one:

1. Open your UniFi console in a browser and sign in (e.g. `https://192.168.1.2`).
2. Go to **Settings → Control Plane → Integrations**.
3. Click **Create API Key** and give it a name (e.g. `uniportical`); set an expiry.
4. Under **UniFi Applications**, enable **Network** and select your site.
   Leave **Site Manager** unchecked.
5. **Copy the key now — it's shown only once**, then put it in `.env` as
   `UNIFI_API_KEY`.

## Configuration — only the un-detectable

Almost everything is discovered from the controller, so the environment carries
only what genuinely can't be. **No values have baked-in defaults**; the
entrypoint validates and fails fast with a clear message if a required one is
missing.

| Var | Required | Notes |
|-----|----------|-------|
| `UNIFI_HOST` | yes | Controller IP/host, e.g. `192.168.1.2` |
| `UNIFI_API_KEY` | yes | Local UniFi API key (or `UNIFI_API_KEY_FILE` for a Docker secret) |
| `UNIPORTICAL_POLL_INTERVAL` | for `poll` | Seconds between reconciles. `-d <seconds>` overrides. |
| `UNIPORTICAL_HOST_IP` | optional | LAN IP for `host`/`bridge` targets. Auto-detected from the route to the controller when running on the **host network**; set it explicitly otherwise. |

**Auto-detected at runtime:** controller **port** (probes 443 / 11443 / 8443),
**site**, and **WAN interface**.

Flags (not env): `-l <label>` · `-d <seconds>` · `-w <wan>` · `-v` verbose ·
`-f` force-update · `-n` dry-run · `--no-prune`.

## Labels

Default label `uniportical.forward`; value is a comma-separated list of
`external[:internal][/proto]`, or the literal `published`:

```
uniportical.forward = "8050/udp"          # udp 8050 -> 8050
uniportical.forward = "8050:80"           # external 8050 -> internal 80
uniportical.forward = "80,443,8050/udp"   # several
uniportical.forward = "published"         # every -p published port
```

Targets resolve to the container's own IP on `macvlan`/`ipvlan`, or the Docker
host's LAN IP on `host`/`bridge`.

```sh
docker run -d --name myapp -l uniportical.forward="8050/udp" your/image
```

## Run

Pulls the published image from Docker Hub — no build step.

**docker compose** (uses the bundled `docker-compose.yml`, which reads `.env`):

```sh
cp .env.example .env                               # fill in UNIFI_HOST + UNIFI_API_KEY
docker compose run --rm uniportical check          # verify key + show discovered port/site/wan
docker compose run --rm uniportical update -v -n   # dry-run: preview, makes no changes
docker compose up -d
docker compose logs -f uniportical                 # watch reconciles
```

**docker run** (equivalent, without compose):

```sh
docker run -d --name uniportical --restart unless-stopped \
  --network host \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -e UNIFI_HOST=192.168.1.2 \
  -e UNIFI_API_KEY=your-unifi-api-key \
  -e UNIPORTICAL_POLL_INTERVAL=30 \
  opop4444/uniportical
```

## Commands

| Command | Behaviour |
|---------|-----------|
| `poll` (default) | Reconcile every `UNIPORTICAL_POLL_INTERVAL` seconds |
| `listen` | Reconcile, then react to container `start`/`die`/`destroy` events |
| `update` | Reconcile once and exit |
| `check` | Verify key + print the auto-detected port / site / WAN |

## Lifecycle & ownership

- Every rule is named `uniportical: <container> <ext>/<proto>`. Identity is
  `(container, external port, protocol)`; the internal `ip:port` is updated in
  place when it changes.
- A container with several ports gets one rule per port; changing/removing one
  port touches only that port's rule.
- **Pruning is on by default**: any `uniportical:` rule no longer wanted
  (container stopped/removed, label or a port removed) is deleted. `--no-prune`
  to disable. Don't hand-name rules with that prefix.

## Conflict guard

- **Among Uniportical rules:** a given `external/proto` can be claimed once;
  later claimants are logged and skipped (containers are processed in sorted
  order, so the winner is deterministic). `tcp_udp` overlaps both `tcp` and
  `udp`; `tcp` and `udp` on the same port from the same owner coexist.
- **Never shares a port with unknowns:** if a **non-Uniportical** rule already
  uses an external port — *for any protocol* — Uniportical logs it and skips,
  and never modifies or deletes rules it doesn't own:
  `CONFLICT: app wants external 8050, already used by a non-Uniportical rule [udp8050] — skipping [uniportical: app 8050/tcp]`.

## Notes

- Needs **read-only** access to the Docker socket (no `docker run`).
- Forwards follow **running** containers (`docker ps`); stopping a container
  drops its forward, starting re-adds it.
- Migrating from portical? Point Uniportical at your old label with
  `-l portical.upnp.forward`.

## License

MIT — see [LICENSE](LICENSE).

## Disclaimer

Not affiliated with, authorized, maintained, sponsored, or endorsed by Ubiquiti
Inc. "UniFi" and "Ubiquiti" are trademarks of Ubiquiti Inc. This project uses
the UniFi API — including some **undocumented endpoints** — which may change
without notice. Provided "as is", without warranty of any kind; use at your own
risk.
