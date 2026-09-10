terraform {
  backend "s3" {
    key          = "webservice/staging/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}