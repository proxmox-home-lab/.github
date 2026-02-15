remote_state {
  backend = "pg"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    schema_name = "${basename(get_repo_root())}/${replace(path_relative_to_include(), ".terragrunt-stack/", "")}"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF2
    provider "github" {
      app_auth {}
    }
  EOF2
}
