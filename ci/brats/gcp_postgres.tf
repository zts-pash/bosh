resource "google_sql_database_instance" "postgres-master" {
  database_version = "POSTGRES_9_6"
  region           = "us-central1"

  settings {
    # Second-generation instance tiers are based on the machine
    # type. See argument reference below.
    tier = "db-f1-micro"
    ip_configuration {
      authorized_networks = [
        {
          name = "concourse"
          value = "104.196.254.104"
        },
        {
          name = "pivotal"
          value = "209.234.137.222/32"
        }
      ]
    }
  }
}

resource "google_sql_database" "postgres" {
  instance  = "${google_sql_database_instance.postgres-master.name}"
  name      = "bosh_director"
}

resource "google_sql_user" "postgres" {
  instance = "${google_sql_database_instance.postgres-master.name}"
  name     = "root"
  password = "${random_string.password.result}"
}

output "gcp_postgres_endpoint" {
  value = "${google_sql_database_instance.postgres-master.first_ip_address}"
}

output "gcp_postgres_instance_name" {
  value = "${google_sql_database_instance.postgres-master.name}"
}
