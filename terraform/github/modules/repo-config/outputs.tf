output "rulesets" {
  description = "IDs de los rulesets creados"
  value = {
    branch_naming    = github_repository_ruleset.branch_naming.id
    main_protection  = github_repository_ruleset.main_protection.id
    tag_protection   = github_repository_ruleset.tag_protection.id
  }
}

output "labels" {
  description = "Labels creados"
  value       = [for label in github_issue_label.labels : label.name]
}
