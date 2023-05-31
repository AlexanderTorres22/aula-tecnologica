[
  {
    "name": "container_${layer}_${stack_id}",
    "image": "${app_image}",
    "cpu": ${fargate_cpu},
    "memory": ${fargate_memory},
    "networkMode": "awsvpc",
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/container_ecs_logs_${name}_${stack_id}",
          "awslogs-region": "${region}",
          "awslogs-stream-prefix": "ecs"
        }
    },
    "portMappings": [
      {
        "containerPort": ${app_port},
        "hostPort": ${app_port}
      }
    ],
    "secrets": ${parameters_secrets},
    "environment": [
      {"name": "environment", "value": "${stack_id}"}
    ]
  }
]