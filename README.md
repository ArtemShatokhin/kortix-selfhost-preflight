# kortix-selfhost-preflight

Preflight checks for a self-hosted Kortix instance, open source and runnable before the first `kortix self-host start`.

Kortix is the open-source AI Operating System: agents, skills, memory and triggers live in one git repository, and sessions run on sandbox machines created with a Platinum API key. A self-hosted instance is one Docker Compose stack on a server you control. Most installs that fail, fail on something the installer never asks about: a missing `api.` record, a port already taken, a shell that cannot reach the Docker daemon, an instance whose `.env` has no domain, or an instance left with sign-up wide open. This script checks those in about ten seconds, before anything starts.

## What it checks

| Step | Check | Why it bites later that day |
|---|---|---|
| 1 | Docker Engine, the Compose plugin, and whether the daemon is reachable as your user | the install adds you to the `docker` group, and the next `kortix self-host` command needs a fresh shell |
| 2 | `<domain>`, `api.<domain>` and `p.<domain>` resolve | Caddy proves the name over HTTP-01, and browser previews need the wildcard |
| 3 | ports 80 and 443 are free on this host | a second web server blocks the certificate |
| 4 | `PLATINUM_API_KEY` is set | without it, sessions do not start |
| 5 | the instance directory and its `.env` | an empty `KORTIX_DOMAIN` means the sandbox cannot call back; an open sign-up window means anyone who reaches the instance can confirm an account for any address, the admin one included |

## Run it

```sh
git clone https://github.com/ArtemShatokhin/kortix-selfhost-preflight
cd kortix-selfhost-preflight
chmod +x preflight.sh
./preflight.sh --domain kortix.example.com
```

Run it again after `kortix self-host configure`, to read the instance directory the CLI wrote, and once more after `start`, beside `kortix self-host doctor`.

Exit codes: `0` no failures, `1` failures to fix, `2` bad usage. Warnings never fail a run: they name the decisions the installer leaves to you.

## Sample output

```
1. Docker Engine and the Compose plugin
  ok    docker 27.3.1
  ok    compose plugin present
  ok    daemon reachable as ops
2. DNS, before the first start
  ok    kortix.example.com resolves to 203.0.113.10
  ok    api.kortix.example.com resolves to 203.0.113.10
  warn  p.kortix.example.com does not resolve: browser previews fall back to a path proxy and doctor fails
3. Ports 80 and 443
  ok    port 80 free locally
  ok    port 443 free locally
4. Keys the instance cannot start without
  warn  PLATINUM_API_KEY is not exported here: configure asks for it, and without it no session starts
5. Instance directory
  warn  no instance directory yet at /home/ops/.config/kortix/self-host/default: run the installer, then kortix self-host configure

preflight: 0 failures
```

## What it does not do

It installs nothing, starts nothing and never calls the Kortix API. It reads the host. For the install itself the order is: install the CLI or run the bootstrap on a bare server, `kortix self-host configure`, `kortix self-host start`, then `kortix self-host doctor`. The operator documentation covers each step: https://kortix.com/docs/host

Nothing here is required to run Kortix.

## The sign-up window, in one line

`kortix self-host configure` can leave sign-up open, and an open instance accepts any address. Close it with `DISABLE_SIGNUP=true` or a working `EMAIL_URL` before the instance is reachable from the internet.

## Related

- Self-hosting documentation: https://kortix.com/docs/host
- The project manifest, which decides what an agent may reach: https://kortix.com/docs/project/manifest

## License

MIT for the scripts in this repository.
