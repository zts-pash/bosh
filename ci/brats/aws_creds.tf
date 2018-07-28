variable "aws_access_key_id" {}
variable "aws_secret_access_key" {}

provider "aws" {
  access_key = "${var.aws_access_key_id}"
  secret_key = "${var.aws_secret_access_key}"
  region     = "us-west-1"
}

resource "random_string" "password" {
  length = 16
  special = true
  override_special = "/@\"
}

output "db_name" {
  value = "bosh_director"
}

output "db_user" {
  value = "root"
}

output "db_password" {
  value = "${random_string.password.result}"
}
