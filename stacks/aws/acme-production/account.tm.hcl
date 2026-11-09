globals {
  environment  = "production"
  account_name = "acme-production"

  # Every production stack uses the server's "production" workflow and needs
  # more checks before apply.
  atlantis_workflow           = "production"
  atlantis_apply_requirements = ["mergeable", "undiverged"]
}
