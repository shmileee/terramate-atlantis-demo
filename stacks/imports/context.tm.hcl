# Writes the account and region globals into every stack that imports this
# file, as Terraform locals.
generate_hcl "_terramate_generated_context.tf" {
  content {
    locals {
      environment  = global.environment
      account_name = global.account_name
      region       = global.region
    }
  }
}
