terraform {
  backend "pg" {
    schema_name = "tfstates/test"
  }
}


resource "null_resource" "name" {
  triggers = {
    "time" = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "echo Hello, World!; sleep 5"
  }
}

