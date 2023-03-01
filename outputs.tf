
locals {
  az_by_region = var.is_cd ? {
    aws-us-east-1c = "use1-az2",
    } : {
    aws-us-east-1c      = "use1-az6",
    aws-us-west-2a      = "usw2-az1",
    aws-eu-west-1a      = "euw1-az2",
    aws-ap-northeast-1a = "apne1-az4",
  }
  all_zones = var.is_cd ? [
    { environment = "dev", region = "aws-us-east-1c", name = "dev.aws-use-1c" },
    { environment = "test", region = "aws-us-east-1c", name = "test.aws-use-1c" },
    { environment = "staging", region = "aws-us-east-1c", name = "staging.aws-use-1c" },
    { environment = "prod", region = "aws-us-east-1c", name = "prod.aws-use-1c" },
    ] : [
    { environment = "dev", region = "aws-us-east-1c" },
    { environment = "test", region = "aws-us-east-1c" },
    { environment = "staging", region = "aws-us-east-1c" },
    { environment = "perf", region = "aws-us-east-1c" },
    { environment = "prod", region = "aws-us-east-1c" },
    { environment = "prod", region = "aws-us-west-2a" },
    { environment = "prod", region = "aws-eu-west-1a" },
    { environment = "prod", region = "aws-ap-northeast-1a" },
  ]
  zones_by_env = {
    for zone in local.all_zones :
    zone.environment => merge(
    { name = "${zone.environment}.${zone.region}", is_cd = var.is_cd, az = local.az_by_region[zone.region], full_name = "${zone.environment}.${zone.region}" }, zone)...
  }
}

output "zones" {
  value = {
    for environment, zones in local.zones_by_env :
    environment => { for zone in zones : replace(zone.region, "-", "_") => zone }
  }
}

output "vespa_cloud_account" {
  value = local.vespa_cloud_account
}
