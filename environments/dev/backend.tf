terraform {
  backend "s3" {
    key          = "webservice/dev/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}