vault {
  address = "https://vault.sergioaten.cloud"
}

template_config {
  exit_on_retry_failure = true
}

exit_after_auth = true

auto_auth {
  method "token_file" {
    config = {
      token_file_path = ".vault_config/token"
    }
  }
}

template {
  destination = ".vault_config/terraform_backend.env"
  perms       = "0600"
  contents    = <<EOF
    # Backend
    {{ with secret "kv/data/proxmox-home-lab/terraform/backend" }}
    {{ range $k, $v := .Data.data }}
    export {{ $k }}="{{ $v }}"{{ end }}{{ end }}
  EOF
}

template {
  destination = ".vault_config/github_provider.env"
  perms       = "0600"
  contents    = <<EOF
    # Github Provider
    {{ with secret "kv/data/proxmox-home-lab/terraform/provider-github" }}{{ range $k, $v := .Data.data }}
    export {{ $k }}="{{ $v }}"{{ end }}{{ end }}
  EOF
}
