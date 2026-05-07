# Create ECR repositories
resource "aws_ecr_repository" "ecr_repository" {
  for_each = var.repositories_to_create

  name                 = "${var.tags["ProjectName"]}/${each.value}"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Name = "${var.tags["ProjectName"]}/${each.value}-repository"
  })
}

# Create ECR lifecycle policy
resource "aws_ecr_lifecycle_policy" "ecr_lifecycle" {
  for_each   = aws_ecr_repository.ecr_repository
  repository = each.value.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
    }]
  })
}