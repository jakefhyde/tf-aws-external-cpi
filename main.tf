data "aws_iam_policy_document" "controlplane_policy" {
  statement {
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVolumes",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifyVolume",
      "ec2:AttachVolume",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteVolume",
      "ec2:DetachVolume",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DescribeVpcs",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:AttachLoadBalancerToSubnets",
      "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateLoadBalancerPolicy",
      "elasticloadbalancing:CreateLoadBalancerListeners",
      "elasticloadbalancing:ConfigureHealthCheck",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteLoadBalancerListeners",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DetachLoadBalancerFromSubnets",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancerPolicies",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
      "iam:CreateServiceLinkedRole",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "controlplane_role" {
  name               = "${var.prefix}-controlplane-role"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": ["ec2.amazonaws.com"]
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_policy" "controlplane_policy" {
  name   = "${var.prefix}-controlplane-policy"
  policy = data.aws_iam_policy_document.controlplane_policy.json
}

resource "aws_iam_role_policy_attachment" "controlplane_attachment" {
  role       = aws_iam_role.controlplane_role.name
  policy_arn = aws_iam_policy.controlplane_policy.arn
}

resource "aws_iam_instance_profile" "controlplane_profile" {
  name = "${var.prefix}-controlplane-profile"
  role = aws_iam_role.controlplane_role.id
}

data "aws_iam_policy_document" "etcd_worker_policy" {
  statement {
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:BatchGetImage"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "etcd_worker_role" {
  name               = "${var.prefix}-etcd-worker-role"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": ["ec2.amazonaws.com"]
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_policy" "etcd_worker_policy" {
  name   = "${var.prefix}-etcd-worker-policy"
  policy = data.aws_iam_policy_document.etcd_worker_policy.json
}

resource "aws_iam_role_policy_attachment" "etcd_worker_attachment" {
  role       = aws_iam_role.etcd_worker_role.name
  policy_arn = aws_iam_policy.etcd_worker_policy.arn
}

resource "aws_iam_instance_profile" "etcd_worker_profile" {
  name = "${var.prefix}-etcd-worker-profile"
  role = aws_iam_role.etcd_worker_role.id
}

resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = {
    Name                          = "${var.prefix}-vpc"
    "kubernetes.io/cluster/${var.prefix}" = "owned"
  }
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.prefix}-gateway"
  }
}

resource "aws_subnet" "subnet" {
  vpc_id = aws_vpc.vpc.id

  cidr_block        = "10.0.0.0/24"
  availability_zone = "${var.aws_region}${var.aws_zone}"

  tags = {
    Name = "${var.prefix}-subnet"
    "kubernetes.io/cluster/${var.prefix}" = "owned"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }

  tags = {
    Name = "${var.prefix}-route-table"
  }
}

resource "aws_route_table_association" "route_table_association" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.route_table.id
}

# Security group to allow all traffic
resource "aws_security_group" "sg_allowall" {
  name        = "${var.prefix}-allowall"
  description = "AWS External CPI Test Security Group - allow all traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Creator = "quickstart"
    "kubernetes.io/cluster/${var.prefix}" = "owned"
  }
}

resource "rancher2_cloud_credential" "aws_creds" {
  provider = rancher2.admin

  name = "aws_creds"
  amazonec2_credential_config {
    access_key = var.aws_access_key
    secret_key = var.aws_secret_key
  }
}

# Create amazonec2 machine config v2
resource "rancher2_machine_config_v2" "etcd" {
  provider = rancher2.admin

  generate_name = "${var.prefix}-downstream-aws-etcd"
  amazonec2_config {
    ami                  = data.aws_ami.ubuntu22.image_id
    region               = var.aws_region
    security_group       = [aws_security_group.sg_allowall.name]
    subnet_id            = aws_subnet.subnet.id
    vpc_id               = aws_vpc.vpc.id
    zone                 = var.aws_zone
    tags                 = "kubernetes.io/cluster/${var.prefix},owned"
    iam_instance_profile = aws_iam_instance_profile.etcd_worker_profile.name
  }
}
# Create amazonec2 machine config v2
resource "rancher2_machine_config_v2" "controlplane" {
  provider = rancher2.admin

  generate_name = "${var.prefix}-downstream-aws-controlplane"
  amazonec2_config {
    ami                  = data.aws_ami.ubuntu22.image_id
    region               = var.aws_region
    security_group       = [aws_security_group.sg_allowall.name]
    subnet_id            = aws_subnet.subnet.id
    vpc_id               = aws_vpc.vpc.id
    zone                 = var.aws_zone
    tags                 = "kubernetes.io/cluster/${var.prefix},owned"
    iam_instance_profile = aws_iam_instance_profile.controlplane_profile.name
  }
}
# Create amazonec2 machine config v2
resource "rancher2_machine_config_v2" "worker" {
  provider = rancher2.admin

  generate_name = "${var.prefix}-downstream-aws-worker"
  amazonec2_config {
    ami                  = data.aws_ami.ubuntu22.image_id
    region               = var.aws_region
    security_group       = [aws_security_group.sg_allowall.name]
    subnet_id            = aws_subnet.subnet.id
    vpc_id               = aws_vpc.vpc.id
    zone                 = var.aws_zone
    tags                 = "kubernetes.io/cluster/${var.prefix},owned"
    iam_instance_profile = aws_iam_instance_profile.etcd_worker_profile.name
  }
}

resource "rancher2_cluster_v2" "downstream_aws" {
  provider = rancher2.admin

  name               = "${var.prefix}-downstream-aws"
  kubernetes_version = var.downstream_kubernetes_version

  rke_config {
    additional_manifest   = <<EOF
      apiVersion: helm.cattle.io/v1
      kind: HelmChart
      metadata:
        name: aws-cloud-controller-manager
        namespace: kube-system
      spec:
        chart: aws-cloud-controller-manager
        repo: https://kubernetes.github.io/cloud-provider-aws
        targetNamespace: kube-system
        bootstrap: true
        valuesContent: |-
          hostNetworking: true
          nodeSelector:
            node-role.kubernetes.io/control-plane: "true"
          args:
            - --configure-cloud-routes=false
            - --v=5
            - --cloud-provider=aws
EOF
    machine_global_config = <<EOF
      cni: "calico"
      disable-kube-proxy: false
      etcd-expose-metrics: false
      cloud-provider-name: "aws"
EOF
    # Used to enable leader migration
#    machine_selector_config {
#      machine_label_selector {
#        match_expressions {
#          key      = "rke.cattle.io/control-plane-role"
#          operator = "In"
#          values   = ["true"]
#        }
#      }
#      config = yamlencode({
#        kube-controller-manager-arg = ["enable-leader-migration"]
#      })
#    }
    machine_selector_config {
      machine_label_selector {
        match_expressions {
          key      = "rke.cattle.io/etcd-role"
          operator = "In"
          values   = ["true"]
        }
      }
      config = yamlencode({
        kubelet-arg = ["cloud-provider=external"]
      })
    }
    machine_selector_config {
      machine_label_selector {
        match_expressions {
          key      = "rke.cattle.io/control-plane-role"
          operator = "In"
          values   = ["true"]
        }
      }
      config = yamlencode({
        disable-cloud-controller    = true
        kube-apiserver-arg          = ["cloud-provider=external"]
        kube-controller-manager-arg = ["cloud-provider=external"]
        kubelet-arg                 = ["cloud-provider=external"]
      })
    }
    machine_selector_config {
      machine_label_selector {
        match_expressions {
          key      = "rke.cattle.io/worker-role"
          operator = "In"
          values   = ["true"]
        }
      }
      config = yamlencode({
        kubelet-arg = ["cloud-provider=external"]
      })
    }

    machine_pools {
      name                         = "etcd"
      cloud_credential_secret_name = rancher2_cloud_credential.aws_creds.id
      control_plane_role           = false
      etcd_role                    = true
      worker_role                  = false
      quantity                     = var.etcd_quantity
      drain_before_delete          = true
      machine_config {
        kind = rancher2_machine_config_v2.etcd.kind
        name = rancher2_machine_config_v2.etcd.name
      }
    }
    machine_pools {
      name                         = "controlplane"
      cloud_credential_secret_name = rancher2_cloud_credential.aws_creds.id
      control_plane_role           = true
      etcd_role                    = false
      worker_role                  = false
      quantity                     = var.controlplane_quantity
      drain_before_delete          = true
      machine_config {
        kind = rancher2_machine_config_v2.controlplane.kind
        name = rancher2_machine_config_v2.controlplane.name
      }
    }
    machine_pools {
      name                         = "worker"
      cloud_credential_secret_name = rancher2_cloud_credential.aws_creds.id
      control_plane_role           = false
      etcd_role                    = false
      worker_role                  = true
      quantity                     = var.worker_quantity
      drain_before_delete          = true
      machine_config {
        kind = rancher2_machine_config_v2.worker.kind
        name = rancher2_machine_config_v2.worker.name
      }
    }
    etcd {
      disable_snapshots      = false
      snapshot_schedule_cron = "0 */4 * * *" # every 6h
      snapshot_retention     = 6
    }
    upgrade_strategy {
      control_plane_concurrency = "1"
      worker_concurrency        = "10%"
      control_plane_drain_options {
        enabled                              = false
        force                                = false
        ignore_daemon_sets                   = true
        ignore_errors                        = false
        delete_empty_dir_data                = true
        disable_eviction                     = false
        grace_period                         = 0
        timeout                              = 10800
        skip_wait_for_delete_timeout_seconds = 600
      }
      worker_drain_options {
        enabled                              = false
        force                                = false
        ignore_daemon_sets                   = true
        ignore_errors                        = false
        delete_empty_dir_data                = true
        disable_eviction                     = false
        grace_period                         = 0
        timeout                              = 10800
        skip_wait_for_delete_timeout_seconds = 600
      }
    }
  }
}
