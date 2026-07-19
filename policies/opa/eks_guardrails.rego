###############################################################################
# OPA / Conftest guardrails for the Terraform PLAN (JSON).
#
# Generate input:  terraform show -json plan.tfplan > plan.json
# Evaluate:        conftest test plan.json --policy policies/opa
###############################################################################
package main

deny[msg] {
	rc := input.resource_changes[_]
	rc.type == "aws_eks_cluster"
	not contains(rc.address, "dev")
	rc.change.after.vpc_config[_].endpoint_public_access == true
	msg := sprintf("EKS cluster '%s' has a public endpoint; only dev may enable it.", [rc.address])
}

deny[msg] {
	rc := input.resource_changes[_]
	rc.type == "aws_eks_cluster"
	count(rc.change.after.encryption_config) == 0
	msg := sprintf("EKS cluster '%s' is missing secrets encryption_config.", [rc.address])
}

deny[msg] {
	rc := input.resource_changes[_]
	rc.type == "aws_eks_cluster"
	required := {"api", "audit", "authenticator", "controllerManager", "scheduler"}
	enabled := {t | t := rc.change.after.enabled_cluster_log_types[_]}
	missing := required - enabled
	count(missing) > 0
	msg := sprintf("EKS cluster '%s' is missing log types: %v", [rc.address, missing])
}

deny[msg] {
	rc := input.resource_changes[_]
	rc.type == "aws_launch_template"
	rc.change.after.metadata_options[_].http_tokens != "required"
	msg := sprintf("Launch template '%s' must set metadata http_tokens = required (IMDSv2).", [rc.address])
}

deny[msg] {
	rc := input.resource_changes[_]
	rc.type == "aws_iam_role_policy"
	doc := json.unmarshal(rc.change.after.policy)
	stmt := doc.Statement[_]
	stmt.Effect == "Allow"
	stmt.Action == "*"
	stmt.Resource == "*"
	msg := sprintf("IAM policy '%s' grants Action:* on Resource:* — forbidden.", [rc.address])
}

deny[msg] {
	rc := input.resource_changes[_]
	rc.type == "aws_iam_policy"
	doc := json.unmarshal(rc.change.after.policy)
	stmt := doc.Statement[_]
	stmt.Effect == "Allow"
	stmt.Action == "*"
	stmt.Resource == "*"
	msg := sprintf("IAM policy '%s' grants Action:* on Resource:* — forbidden.", [rc.address])
}

deny[msg] {
	rc := input.resource_changes[_]
	rc.type == "aws_ecr_repository"
	rc.change.after.image_tag_mutability != "IMMUTABLE"
	msg := sprintf("ECR repository '%s' must be IMMUTABLE.", [rc.address])
}

deny[msg] {
	rc := input.resource_changes[_]
	rc.type == "aws_s3_bucket_public_access_block"
	rc.change.after.block_public_acls == false
	msg := sprintf("S3 public access block '%s' must set block_public_acls = true.", [rc.address])
}
