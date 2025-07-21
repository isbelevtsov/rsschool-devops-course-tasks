resource "aws_ecr_repository" "flask_app" {
  name                 = "${var.project_name}-flask-app-${var.environment_name}"
  image_tag_mutability = "IMMUTABLE" # or "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-flask-app-${var.environment_name}"
  }
}

resource "aws_ecr_lifecycle_policy" "flask_app_lifecycle" {
  repository = aws_ecr_repository.flask_app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Expire untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2,
        description  = "Keep the last 5 tagged images"
        selection = {
          tagStatus   = "tagged"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
