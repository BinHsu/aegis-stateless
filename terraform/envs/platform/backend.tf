terraform {
  backend "s3" {
    # Partial config — bucket, dynamodb_table, region, encrypt are passed via
    # -backend-config flags (see Makefile target `backend.hcl`, derived from
    # bootstrap's outputs). Hardcoding them here would force a re-edit on
    # every fork of the repo.
    key = "platform/terraform.tfstate"
  }
}
