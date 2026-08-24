output "db_host" {
  description = "RDS instance DNS name"
  value = module.rds.db_host
}

/*output "db_connection_strings" {
  value = module.rds.connection_strings
<<<<<<< HEAD
}*/
=======
  sensitive = true
}
>>>>>>> 7fc95b2e7844ab9a62c8f89702bce04552ffa0a1
