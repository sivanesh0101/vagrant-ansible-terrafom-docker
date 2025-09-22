terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}



resource "docker_image" "quiz_app" {
  name = "quiz-app:latest"

  build {
    context    = "${path.module}/IaC-quiz"
    dockerfile = "Dockerfile"
  }

  triggers = {
   # app_code = filesha256("${path.module}/../Iac-quiz/app.py")
   app_code = filesha256("${path.module}/IaC-quiz/app.py")

  }
  keep_locally = false
}


## running docker
resource "docker_container" "quiz_app" {
  name  = "quiz_app"
  image = docker_image.quiz_app.image_id
  must_run = true
  restart = "always"

  ports {
    internal = 8080
    external = 8080
  }

  lifecycle {
    replace_triggered_by = [docker_image.quiz_app]
    create_before_destroy  = false   # destroy old before creating new
  }
}


# variable "app_port" {
#   description = "Port to expose quiz app"
#   type        = number
#   default     = 8080
# }



# data "external" "host_ip" {
#   program = ["${path.module}/get_ip.sh"]
# }
