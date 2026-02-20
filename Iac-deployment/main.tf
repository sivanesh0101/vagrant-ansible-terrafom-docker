terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "= 3.6.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

resource "random_string" "name_suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "random_integer" "host_port" {
  min = 8000
  max = 8999
}

locals {
  effective_container_name = coalesce(var.container_name, "quiz_app_${random_string.name_suffix.result}")
  effective_external_port  = coalesce(var.external_port, random_integer.host_port.result)
}

# Pull a prebuilt image from Docker Hub (or any registry)
resource "docker_image" "quiz_app" {
  name         = var.image
  keep_locally = false
}

# Run the IaC Quiz app container
resource "docker_container" "quiz_app" {
  name     = local.effective_container_name
  image    = docker_image.quiz_app.image_id
  must_run = true
  restart  = "always"

  ports {
    internal = 8080
    external = local.effective_external_port
  }

  lifecycle {
    replace_triggered_by = [docker_image.quiz_app]
    create_before_destroy  = false   # destroy old before creating new
  }
}

