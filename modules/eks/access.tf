###############################################################################
# EKS access entries — map IAM principals to Kubernetes access via the API
# (replaces hand-editing the aws-auth ConfigMap)
###############################################################################

resource "aws_eks_access_entry" "this" {
  for_each = var.access_entries

  cluster_name      = aws_eks_cluster.this.name
  principal_arn     = each.value.principal_arn
  kubernetes_groups = try(each.value.kubernetes_groups, null)
  type              = try(each.value.type, "STANDARD")
  tags              = var.tags
}

resource "aws_eks_access_policy_association" "this" {
  # Flatten { entry_key => { policies = [...] } } into one association per policy.
  for_each = { for assoc in flatten([
    for k, v in var.access_entries : [
      for p in try(v.policy_associations, []) : {
        key           = "${k}-${p.policy_arn}"
        principal_arn = v.principal_arn
        policy_arn    = p.policy_arn
        access_scope  = p.access_scope
      }
    ]
  ]) : assoc.key => assoc }

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value.principal_arn
  policy_arn    = each.value.policy_arn

  access_scope {
    type       = each.value.access_scope.type
    namespaces = try(each.value.access_scope.namespaces, null)
  }

  depends_on = [aws_eks_access_entry.this]
}
