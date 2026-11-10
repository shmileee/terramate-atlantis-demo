# terramate-atlantis-demo

A small [Terramate](https://terramate.io) repository planned by
[Atlantis](https://www.runatlantis.io). Atlantis' project list,
`atlantis.yaml`, isn't committed:
[terramate-atlantis-config](https://github.com/devops-roast/terramate-atlantis-config)
generates it from the stacks in every pull request.

This is the example repository for
[Generating Atlantis config from Terramate stacks](https://oponomarov.com/blog/posts/generating-atlantis-config-from-terramate-stacks/),
which walks through everything below. The follow-up post,
[Planning Terramate stacks in Atlantis without generated code](https://oponomarov.com/blog/posts/planning-terramate-stacks-in-atlantis-without-generated-code/),
uses [terramate-atlantis-autoplan](https://github.com/shmileee/terramate-atlantis-autoplan),
which leaves Terramate's generated code out of Git as well.

## What to look at

| Path | What it shows |
| --- | --- |
| [`stacks/aws/acme-production/account.tm.hcl`](stacks/aws/acme-production/account.tm.hcl) | Atlantis settings for every stack in one account |
| [`stacks/aws/acme-production/eu-west-1/skipped`](stacks/aws/acme-production/eu-west-1/skipped/stack.tm.hcl) | a stack that isn't an Atlantis project |
| [`stacks/aws/acme-production/eu-west-1/manual`](stacks/aws/acme-production/eu-west-1/manual/stack.tm.hcl) | a stack planned only on request |
| [`.terramate-atlantis.yaml`](.terramate-atlantis.yaml) | defaults for every project |
| [`atlantis/repos.yaml`](atlantis/repos.yaml) | the hook that generates `atlantis.yaml`, and the `production` workflow |
| [`atlantis/docker-compose.yaml`](atlantis/docker-compose.yaml) | the Atlantis server: a failing hook stops the run, and plans use the `merge` checkout strategy |

The stacks only hold `terraform_data` resources, so they plan without cloud
credentials. Tool versions are pinned in [`mise.toml`](mise.toml).

## The pull requests

Each pull request isolates one behavior, and its description says what to
look for. Their conversations are locked, so Atlantis' comments stay as they
were; to try a change of your own, fork the repository and run it yourself.

| Pull request | Changes | Atlantis plans |
| --- | --- | --- |
| [#1](https://github.com/shmileee/terramate-atlantis-demo/pull/1) | adds a development stack, `new-stack` | the new stack |
| [#2](https://github.com/shmileee/terramate-atlantis-demo/pull/2) | `network` in both accounts | both, production with `terraform validate` first |
| [#3](https://github.com/shmileee/terramate-atlantis-demo/pull/3) | `skipped`, `manual` and development `app` | `app`; `manual` only after `atlantis plan -p` |

## Running it yourself

Fork the repository, then:

```sh
mise install   # the pinned tools
make app       # once: create a GitHub App for Atlantis, install it on the fork
make up        # start Atlantis, reachable by GitHub through a free tunnel
make e2e       # open the example pull requests and check Atlantis' answers
make down
```
