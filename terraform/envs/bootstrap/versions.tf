terraform {
  required_version = "~> 1.9"

  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.60" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }

  # Bootstrap stays on LOCAL state forever. Its only purpose is to create the
  # S3 bucket + DynamoDB table that downstream envs use as their remote
  # backend. Migrating bootstrap's own state into that same bucket would
  # create a chicken-and-egg cycle.
}
