# Security Group para RDS
resource "aws_security_group" "rds" {
  name_prefix = "${var.cluster_name}-rds-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "PostgreSQL from EKS Fargate pods"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]  # Fargate pods en subnets públicas
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-rds-sg"
    }
  )
}

# Subnet Group para RDS
resource "aws_db_subnet_group" "postgres" {
  name       = "${var.cluster_name}-db-subnet"
  subnet_ids = module.vpc.private_subnets

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-db-subnet"
    }
  )
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "postgres" {
  identifier     = "${var.cluster_name}-postgres"
  engine         = "postgres"
  engine_version = "15.15"

  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = var.environment == "prod" ? 7 : 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  skip_final_snapshot       = var.environment == "dev" ? true : false
  final_snapshot_identifier = var.environment == "dev" ? null : "${var.cluster_name}-final-snapshot"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-postgres"
    }
  )
}

# Kubernetes Secret para almacenar credenciales de DB
resource "kubernetes_secret" "postgres_credentials" {
  metadata {
    name      = "postgres-credentials"
    namespace = kubernetes_namespace.retrogamecloud.metadata[0].name
  }

  data = {
    POSTGRES_USER        = var.db_username
    POSTGRES_PASSWORD    = var.db_password
    POSTGRES_DB          = var.db_name
    POSTGRES_HOST        = aws_db_instance.postgres.address
    POSTGRES_PORT        = tostring(aws_db_instance.postgres.port)
    # Para servicios Node.js (pg driver soporta no-verify)
    DATABASE_URL         = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.db_name}?ssl=true&sslmode=no-verify"
    # Para psql CLI (no soporta no-verify, usa require)
    DATABASE_URL_PSQL    = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.db_name}?sslmode=require"
  }

  depends_on = [
    module.eks,
    aws_db_instance.postgres
  ]
}

# ConfigMap para init script de PostgreSQL
resource "kubernetes_config_map" "postgres_init" {
  metadata {
    name      = "postgres-init-script"
    namespace = kubernetes_namespace.retrogamecloud.metadata[0].name
  }

  data = {
    "init.sql" = <<-EOT
      -- Crear tablas si no existen
      CREATE TABLE IF NOT EXISTS games (
        id VARCHAR(255) PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        slug VARCHAR(255) UNIQUE NOT NULL,
        description TEXT,
        file_url VARCHAR(255) NOT NULL,
        thumbnail_url VARCHAR(255),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        username VARCHAR(255) UNIQUE NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS scores (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        game_id VARCHAR(255) REFERENCES games(id) ON DELETE CASCADE,
        score INTEGER NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(user_id, game_id)
      );

      -- Insertar juegos seed data
      INSERT INTO games (id, title, slug, description, file_url, thumbnail_url) VALUES
        ('1', 'DOOM', 'doom', 'Iconic first-person shooter', '/juegos/doom.jsdos', '/img/doom.png'),
        ('2', 'Duke Nukem 3D', 'duke3d', 'Action-packed FPS classic', '/juegos/duke3d.jsdos', '/img/duke3d.png'),
        ('3', 'Wolfenstein 3D', 'wolf', 'Pioneering first-person shooter', '/juegos/wolf.jsdos', '/img/wolf.png'),
        ('4', 'Digger', 'digger', 'Classic arcade digging game', '/juegos/digger.jsdos', '/img/digger.png'),
        ('5', 'Tetris', 'tetris', 'Timeless puzzle game', '/juegos/tetris.jsdos', '/img/tetris.png'),
        ('6', 'Street Fighter II', 'streetfighter2', 'Legendary fighting game', '/juegos/streetfighter2.jsdos', '/img/streetfighter2.png'),
        ('7', 'Mortal Kombat', 'mortalkombat', 'Brutal fighting game', '/juegos/mortalkombat.jsdos', '/img/mortalkombat.png'),
        ('8', 'The Lost Vikings', 'lostvikings', 'Puzzle-platformer adventure', '/juegos/lostvikings.jsdos', '/img/lostvikings.png'),
        ('9', 'Heroes of Might and Magic II', 'heroesofmightandmagic2', 'Turn-based strategy game', '/juegos/heroesofmightandmagic2.jsdos', '/img/heroesofmightandmagic2.png'),
        ('10', 'Dangerous Dave 2', 'dangerousdave2', 'Platform adventure game', '/juegos/dangerousdave2.jsdos', '/img/dangerousdave2.png')
      ON CONFLICT (slug) DO NOTHING;
    EOT
  }

  depends_on = [module.eks]
}
