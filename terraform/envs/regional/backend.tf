terraform {
  backend "s3" {
    # Partial config — bucket, key, dynamodb_table, region, encrypt all
    # passed via -backend-config flags by the Makefile. The key includes
    # the region (e.g. `regional/eu-central-1/terraform.tfstate`) so each
    # region's apply has its own state file and its own lock — per-region
    # blast-radius isolation.
  }
}
