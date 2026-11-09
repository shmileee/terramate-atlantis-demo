# terramate-atlantis-demo

A small [Terramate](https://terramate.io) repository planned by
[Atlantis](https://www.runatlantis.io). Atlantis' project list,
`atlantis.yaml`, isn't committed:
[terramate-atlantis-config](https://github.com/devops-roast/terramate-atlantis-config)
generates it from the stacks in every pull request.

- Blog post: [Generating Atlantis config from Terramate stacks](https://oponomarov.com/blog/posts/generating-atlantis-config-from-terramate-stacks/)
- Next step, with Terramate's generated code left out of git as well:
  [terramate-atlantis-autoplan](https://github.com/shmileee/terramate-atlantis-autoplan)

## What to look at

| Path | What it shows |
| --- | --- |
| [`stacks/aws/acme-production/account.tm.hcl`](stacks/aws/acme-production/account.tm.hcl) | Atlantis settings for every stack in one account |
| [`stacks/aws/acme-production/eu-west-1/skipped`](stacks/aws/acme-production/eu-west-1/skipped/stack.tm.hcl) | a stack that isn't an Atlantis project |
| [`stacks/aws/acme-production/eu-west-1/manual`](stacks/aws/acme-production/eu-west-1/manual/stack.tm.hcl) | a stack planned only on request |
| [`.terramate-atlantis.yaml`](.terramate-atlantis.yaml) | defaults for every project |
| [`atlantis/repos.yaml`](atlantis/repos.yaml) | the hook that generates `atlantis.yaml`, and the `production` workflow |
| [Pull requests](https://github.com/shmileee/terramate-atlantis-demo/pulls) | one per example, with what to look for in the description |

The stacks only hold `terraform_data` resources, so they plan without cloud
credentials. Tool versions are pinned in [`mise.toml`](mise.toml).

## Running it yourself

Fork the repository, then:

```sh
mise install   # the pinned tools
make app       # once: create a GitHub App for Atlantis, install it on the fork
make up        # start Atlantis, reachable by GitHub through a free tunnel
make e2e       # open the example pull requests and check Atlantis' answers
make down
```
