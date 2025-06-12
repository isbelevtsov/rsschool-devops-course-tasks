terraform {
  backend "s3" {
    bucket         = "rsschool-bootstrap-terraform-state"
    key            = "global/rsschool/terraform-project.tfstate"
    region         = "eu-north-1"
    encrypt        = true
    use_lockfile   = true
    profile        = "rsschool_user"
  }
}
