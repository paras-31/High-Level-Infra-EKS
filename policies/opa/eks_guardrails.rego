###############################################################################
# OPA / Conftest guardrails for the Terraform PLAN (JSON).
#
# Generate input:  terraform show -json plan.tfplan > plan.json
# Evaluate:        conftest test plan.json --policy policies/opa
#
# These are org governance rules that go beyond generic linters — they encode
# "how WE run EKS": private prod endpoints, encrypted secrets, no wildcard IAM,
# mandatory tagging, IMDSv2, immutable ECR tags.
###############################################################################
package main

import future.keywords.in

# Collect planned resources of a given type.
resources[t] := rs {
	some t
	rs := [r | r := input.resource_changes[_]; r.type == t]
}

deny contains msg if {
	# prod/staging clusters must NOT expose a public API endpoint.
	rc := input.resource_changes[_]
	rc.type == "aws_eks_cluster"
	not contains(rc.address, "dev")
	rc.change.after.vpc_config[_].endpoint_public_access == true
	msg := sprintf("EKS cluster '%s' has a public endpoint; only dev may enable it.", [rc.address])
}

deny contains msg if {
	# Every EKS cluster must encrypt secrets with a KMS key.
	rc := input.resource_changes[_]
	rc.type == "aws_eks_cluster"
	count(rc.change.after.encryption_config) == 0
	msg := sprintf("EKS cluster '%s' is missing secrets encryption_config.", [rc.address])
}

deny contains msg if {
	# Control-plane logging must be fully enabled.
	rc := input.resource_changes[_]
	rc.type == "aws_eks_cluster"
	required := {"api", "audit", "authenticator", "controllerManager", "scheduler"}
	enabled := {t | t := rc.change.after.enabled_cluster_log_types[_]}
	missing := required - enabled
	count(missing) > 0
	msg := sprintf("EKS cluster '%s' is missing log types: %v", [rc.address, missing])
}

deny contains msg if {
	# Launch templates must enforce IMDSv2.
	rc := input.resource_changes[_]
	rc.type == "aws_launch_template"
	rc.change.after.metadata_options[_].http_tokens != "required"
	msg := sprintf("Launch template '%s' must set metadata http_tokens = required (IMDSv2).", [rc.address])
}

deny contains msg if {
	# No inline IAM policy may grant Action "*" on Resource "*".
	rc := input.resource_changes[_]
	rc.type in {"aws_iam_role_policy", "aws_iam_policy"}
	doc := json.unmarshal(rc.change.after.policy)
	stmt := doc.Statement[_]
	stmt.Effect == "Allow"
	stmt.Action == "*"
	stmt.Resource == "*"
	msg := sprintf("IAM policy '%s' grants Action:* on Resource:* — forbidden.", [rc.address])
}

deny contains msg if {
	# ECR repositories must use immutable tags.
	rc := input.resource_changes[_]
	rc.type == "aws_ecr_repository"
	rc.change.after.image_tag_mutability != "IMMUTABLE"
	msg := sprintf("ECR repository '%s' must be IMMUTABLE.", [rc.address])
}

deny contains msg if {
	# S3 buckets must block all public access (checked via the PAB resource existing
	# is enforced elsewhere; here we forbid explicitly-public ACLs).
	rc := input.resource_changes[_]
	rc.type == "aws_s3_bucket_public_access_block"
	rc.change.after.block_public_acls == false
	msg := sprintf("S3 public access block '%s' must set block_public_acls = true.", [rc.address])
}
