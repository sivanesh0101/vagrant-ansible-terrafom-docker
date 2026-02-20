terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "= 3.6.2"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# Pull a prebuilt image from Docker Hub (or any registry)
resource "docker_image" "quiz_app" {
  name         = var.image
  keep_locally = false
}

# Run the IaC Quiz app container
resource "docker_container" "quiz_app" {
  name     = var.container_name
  image    = docker_image.quiz_app.image_id
  must_run = true
  restart  = "always"

  ports {
    internal = 8080
    external = var.external_port
  }

  lifecycle {
    replace_triggered_by = [docker_image.quiz_app]
    create_before_destroy  = false   # destroy old before creating new
  }
}

