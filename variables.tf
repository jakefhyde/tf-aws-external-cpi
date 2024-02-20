# Generic variables
variable "prefix" {
  type    = string
  default = "tf-aws-external-cpi-test"
}

# AWS vars
variable "aws_access_key" {
  type = string
}

variable "aws_secret_key" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "aws_zone" {
  type = string
  default = "a"
}

# Rancher vars
variable "rancher_version" {
  type    = string
  default = "v2.8.1"
}

variable "rancher_token" {
  type = string
}

variable "rancher_url" {
  type = string
}

# Downstream vars
variable "downstream_kubernetes_version" {
  type = string
  default = "v1.27.8+rke2r1"
}

variable "etcd_quantity" {
  type = number
  default = 3
}

variable "controlplane_quantity" {
  type = number
  default = 2
}

variable "worker_quantity" {
  type = number
  default = 3
}