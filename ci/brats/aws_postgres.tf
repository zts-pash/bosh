resource "aws_db_instance" "postgres" {
  allocated_storage    = 10
  storage_type         = "gp2"
  engine               = "postgres"
  engine_version       = "9.6.8"
  instance_class       = "db.t2.micro"
  skip_final_snapshot  = true
  name                 = "bosh_director"
  username             = "root"
  password             = "${random_string.password.result}"
  vpc_security_group_ids = ["${aws_security_group.allow-db-access.id}"]
  db_subnet_group_name = "${aws_db_subnet_group.default.id}"
  parameter_group_name = "default.postgres9.6"
  publicly_accessible    = true
}

output "aws_postgres_endpoint" {
  value = "${aws_db_instance.postgres.endpoint}"
}
