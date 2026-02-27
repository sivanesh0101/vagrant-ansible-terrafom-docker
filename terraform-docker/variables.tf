variable "vm_ip" {
  type        = string
  description = "Vagrant VM private_network IP"
  default     = "192.168.56.10"  # keep here or in terraform.tfvars
}

variable "app_port" {
  type        = number
  description = "App port inside the VM (guest port)"
  default     = 8080
}

# Docker container name (must be unique on the Docker host)
variable "container_name" {
  type        = string
  description = "Docker container name to create (must be unique on the VM)"
  default     = "quiz_app"
}

# Host port to expose the app on (maps to container port 8080)
variable "external_port" {
  type        = number
  description = "Host port to map to container's 8080"
  default     = 8080
}
