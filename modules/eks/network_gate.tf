# Gates node group creation until VPC endpoints + DNS wait complete.
resource "terraform_data" "network_ready" {
  input = "${var.network_ready_trigger}:${join(",", var.vpc_endpoint_ids)}"
}
