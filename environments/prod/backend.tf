terraform {
  backend "s3" {
    key          = "webservice/prod/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}