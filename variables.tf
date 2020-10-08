variable "region" {
  default = "eu-central-1"
  type = string
}

variable "aws" {
    default = {
        id = ""
        key=""
    }
}

variable "profile" {
  default = "default"
  type = string
}

variable "stage" {
  default = "prod"
  type = string
}

variable "api_name" {
  type = string
}

variable "api_description" {
  type = string
}

variable "domain" {
  default = "techunter.io"
  type = string
}

variable "subdomain" {
  type = string
}

variable "ignition_file"{
    type = string
    default = "example.fcc"
}