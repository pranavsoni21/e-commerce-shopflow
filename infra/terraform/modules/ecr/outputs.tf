output "ecr_repositories_urls" {
  value = [for repo in aws_ecr_repository.ecr_repository : repo.repository_url]
}

output "registry_id" {
  value = values(aws_ecr_repository.ecr_repository)[0].registry_id
}

output "ecr_repository_arns" {
  value = [for repo in aws_ecr_repository.ecr_repository : repo.arn]
}