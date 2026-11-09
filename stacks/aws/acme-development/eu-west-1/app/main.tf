resource "terraform_data" "this" {
  input = "${local.account_name}-${local.region}-app-v2"
}
