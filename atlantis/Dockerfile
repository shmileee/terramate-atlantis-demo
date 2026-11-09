# Atlantis with the two binaries its steps and the pre-workflow hook call:
# terraform (the image no longer ships it) and terramate-atlantis-config.
FROM ghcr.io/runatlantis/atlantis:v0.49.0

ARG TERRAFORM_VERSION=1.15.8
ARG TMAC_VERSION=1.3.0
ARG TARGETARCH

USER root

RUN set -eux; \
	arch="${TARGETARCH:-amd64}"; \
	tmp="$(mktemp -d)"; cd "$tmp"; \
	hc=https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}; \
	curl -fsSLO "$hc/terraform_${TERRAFORM_VERSION}_linux_${arch}.zip"; \
	curl -fsSLO "$hc/terraform_${TERRAFORM_VERSION}_SHA256SUMS"; \
	grep " terraform_${TERRAFORM_VERSION}_linux_${arch}.zip\$" \
		"terraform_${TERRAFORM_VERSION}_SHA256SUMS" | sha256sum -c -; \
	unzip -q "terraform_${TERRAFORM_VERSION}_linux_${arch}.zip" terraform -d /usr/local/bin; \
	tmac=https://github.com/devops-roast/terramate-atlantis-config/releases/download/v${TMAC_VERSION}; \
	curl -fsSLO "$tmac/terramate-atlantis-config_${TMAC_VERSION}_linux_${arch}.tar.gz"; \
	curl -fsSL -o tmac-checksums.txt "$tmac/checksums.txt"; \
	grep " terramate-atlantis-config_${TMAC_VERSION}_linux_${arch}.tar.gz\$" tmac-checksums.txt | sha256sum -c -; \
	tar -xzf "terramate-atlantis-config_${TMAC_VERSION}_linux_${arch}.tar.gz" \
		-C /usr/local/bin terramate-atlantis-config; \
	cd /; rm -rf "$tmp"; \
	terraform version; terramate-atlantis-config version

USER atlantis
