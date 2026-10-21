# Claude Code against a local endpoint

Claude Code reads one variable to decide where its requests go. That variable, not the installer, decides whether an install is self-hosted. Kortix is the open-source AI Operating System: your agents, their skills, your company memory, and every connector in one git repo you own, with the agents working on real cloud computers. The preflight here checks the server. It never asks where the model lives, and that question takes one command to settle before an install.

## The variable that decides

`ANTHROPIC_BASE_URL` points Claude Code at a gateway. `/status` shows it as "Anthropic base URL" only when it is set, so a missing line is itself a finding. The credential goes in one of two variables, and the choice is not cosmetic: `ANTHROPIC_AUTH_TOKEN` is sent as `Authorization: Bearer`, `ANTHROPIC_API_KEY` as `x-api-key`. A credential in the wrong variable arrives in a header the gateway does not read, and the request fails with 401.

Anthropic's documentation notes the limit of the URL alone: with `ANTHROPIC_BASE_URL` set and no gateway credential, a saved claude.ai login stays the active credential and its limits still apply ([connect Claude Code to a gateway](https://code.claude.com/docs/en/llm-gateway-connect)). The traffic moved. The account behind it did not.

## What the preflight in this repo checks

Run it against a local name and it reports on the host it stands on:

```console
$ ./preflight.sh --domain localhost
  ok    docker 29.9.1
  ...
  ok    localhost resolves to ::1
  FAIL  api.localhost does not resolve: Caddy cannot get a certificate until it does
preflight: 1 failure(s) to fix before start
```

Against `--domain kortix.example.com` it reports two failures, both DNS. Its five sections cover Docker and its daemon, the three hostnames, ports 80 and 443, `PLATINUM_API_KEY`, and the instance `.env` (`KORTIX_DOMAIN`, and whether sign-up is closed). That is the host, not the model endpoint.

## The check that answers the model question

Take the one-token request from Anthropic's page and point it at the URL you intend to use:

```bash
curl -sS -w '\n%{http_code}\n' -X POST "$ANTHROPIC_BASE_URL/v1/messages" \
  -H "Authorization: Bearer $ANTHROPIC_AUTH_TOKEN" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model": "claude-sonnet-4-6", "max_tokens": 1, "messages": [{"role": "user", "content": "."}]}'
```

Three answers are possible. Nothing listening: `curl: (7) Failed to connect to 127.0.0.1 port 8787`, exit code 7. Something listening that is not a Messages API: a static server replied `501` with `Unsupported method ('POST')`. A hosted API answering for itself: `https://api.anthropic.com` returned `401` with `{"type":"error","error":{"type":"authentication_error","message":"Invalid bearer token"}}`.

The last result is the one to sit with. A 401 from Anthropic proves the endpoint answered, speaks the Anthropic format, and received a request that left your network. Pointing a local variable at a remote service does not make the service local. The test passes only when an address you operate returns a JSON body starting `{"id":"msg_`, or an error naming a model, because either one means your endpoint authenticated the call first.

## Where this lands

A Claude Code install is a client plus an address. If the address is a provider's, the tokens, the transcript and the bill are theirs. Kortix applies the same idea to compute: one isolated sandbox per session. Each session has its own isolated machine and branch, and the endpoint it calls is a decision separate from the machine it runs on. Models are a separate choice too: any model provider with your own keys.

The session side runs on a sandbox provider, which is why `PLATINUM_API_KEY` is in the preflight at all.

The split between what runs on your hardware and what stays with a vendor is the subject of [self-hosted Claude Code and where an open-source harness draws the line](https://opensourceclaudecowork.com/self-hosted-claude-code).

## Sources
- https://code.claude.com/docs/en/llm-gateway-connect · https://code.claude.com/docs/en/llm-gateway
- https://github.com/ArtemShatokhin/kortix-selfhost-preflight/blob/main/preflight.sh · https://opensourceclaudecowork.com/self-hosted-claude-code
