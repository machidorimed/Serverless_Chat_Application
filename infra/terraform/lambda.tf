# backend/ディレクトリ(src/ + node_modules/ + package.json)をまとめてZIP化する。
# 事前に `cd backend && npm install` を実行して node_modules を生成しておくこと。
# (AWS SDK v3クライアントはLambdaのNode.jsマネージドランタイムに同梱されているため、
#  実際にnode_modulesへ含める必要があるのは aws-jwt-verify のみ)
data "archive_file" "backend" {
  type        = "zip"
  source_dir  = "${path.module}/../../backend"      #　zipファイルにするディレクトリ
  output_path = "${path.module}/.build/backend.zip" #　生成したZipファイル名
  excludes    = ["package-lock.json"]               #　上記のディレクトリからZipファイルにしないファイル
}

# ------------------------------------------------------------#
#  AWS Lambda
# ------------------------------------------------------------#
# ---------- connect ----------

resource "aws_cloudwatch_log_group" "connect" {
  name              = "/aws/lambda/${var.project_name}-connect"
  retention_in_days = var.log_retention_days
}

resource "aws_iam_role" "connect" {
  name = "${var.project_name}-connect-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "connect" {
  name = "${var.project_name}-connect-policy"
  role = aws_iam_role.connect.id

  # LambdaにCloudWatch Logsへの書き込み権限と
  # DynamoDBへConnectionsテーブルの新規作成権限を付与
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.connect.arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.connections.arn
      },
    ]
  })
}

resource "aws_lambda_function" "connect" {
  function_name = "${var.project_name}-connect"
  role          = aws_iam_role.connect.arn
  handler       = "src/connect.handler"
  runtime       = "nodejs20.x" # 実行環境。Node.js20指定
  timeout       = 10           # 最大実行時間(秒)

  filename         = data.archive_file.backend.output_path         # 参照するZipファイル名
  source_code_hash = data.archive_file.backend.output_base64sha256 # 差分検知。Zipに変更がなければ呼び出しをスキップ。

  # connect.jsに渡す環境変数
  environment {
    variables = {
      CONNECTIONS_TABLE   = aws_dynamodb_table.connections.name
      USER_POOL_ID        = aws_cognito_user_pool.this.id
      USER_POOL_CLIENT_ID = aws_cognito_user_pool_client.spa.id
    }
  }

  # ロググループ作成後にLambda関数を作成する設定。
  # これがないとログが正しく記録されない可能性あり。
  depends_on = [aws_cloudwatch_log_group.connect]
}

# ---------- disconnect ----------

resource "aws_cloudwatch_log_group" "disconnect" {
  name              = "/aws/lambda/${var.project_name}-disconnect"
  retention_in_days = var.log_retention_days
}

resource "aws_iam_role" "disconnect" {
  name = "${var.project_name}-disconnect-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "disconnect" {
  name = "${var.project_name}-disconnect-policy"
  role = aws_iam_role.disconnect.id

  # LambdaにCloudWatch Logsへの書き込み権限と
  # DynamoDBへConnectionsテーブルの削除権限を付与
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.disconnect.arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:DeleteItem"]
        Resource = aws_dynamodb_table.connections.arn
      },
    ]
  })
}

resource "aws_lambda_function" "disconnect" {
  function_name = "${var.project_name}-disconnect"
  role          = aws_iam_role.disconnect.arn
  handler       = "src/disconnect.handler"
  runtime       = "nodejs20.x"
  timeout       = 10

  filename         = data.archive_file.backend.output_path
  source_code_hash = data.archive_file.backend.output_base64sha256

  environment {
    variables = {
      CONNECTIONS_TABLE = aws_dynamodb_table.connections.name
    }
  }

  depends_on = [aws_cloudwatch_log_group.disconnect]
}

# ---------- sendMessage ----------

resource "aws_cloudwatch_log_group" "send_message" {
  name              = "/aws/lambda/${var.project_name}-send-message"
  retention_in_days = var.log_retention_days
}

resource "aws_iam_role" "send_message" {
  name = "${var.project_name}-send-message-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "send_message" {
  name = "${var.project_name}-send-message-policy"
  role = aws_iam_role.send_message.id

  # LambdaにCloudWatch Logsへの書き込み権限と
  # DynamoDBのMessagesテーブルの作成と更新、
  # Connectionsテーブルへの読み取り・削除(切断済みの場合のみ)、
  # WebSocket接続へのメッセージ配信権限を付与
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.send_message.arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.messages.arn
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:Scan", "dynamodb:DeleteItem"]
        Resource = aws_dynamodb_table.connections.arn
      },
      {
        Effect   = "Allow"
        Action   = ["execute-api:ManageConnections"]
        Resource = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${aws_apigatewayv2_api.chat.id}/*/POST/@connections/*"
      },
    ]
  })
}

resource "aws_lambda_function" "send_message" {
  function_name = "${var.project_name}-send-message"
  role          = aws_iam_role.send_message.arn
  handler       = "src/sendMessage.handler"
  runtime       = "nodejs20.x"
  timeout       = 10

  filename         = data.archive_file.backend.output_path
  source_code_hash = data.archive_file.backend.output_base64sha256

  environment {
    variables = {
      CONNECTIONS_TABLE = aws_dynamodb_table.connections.name
      MESSAGES_TABLE    = aws_dynamodb_table.messages.name
    }
  }

  depends_on = [aws_cloudwatch_log_group.send_message]
}

# ---------- getHistory ----------

resource "aws_cloudwatch_log_group" "get_history" {
  name              = "/aws/lambda/${var.project_name}-get-history"
  retention_in_days = var.log_retention_days
}

resource "aws_iam_role" "get_history" {
  name = "${var.project_name}-get-history-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "get_history" {
  name = "${var.project_name}-get-history-policy"
  role = aws_iam_role.get_history.id

  # LambdaにCloudWatch Logsへの書き込み権限と
  # Messagesテーブルの直近履歴の読み取り権限、
  # リクエストしてきた接続への履歴配信権限を付与
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.get_history.arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:Query"]
        Resource = aws_dynamodb_table.messages.arn
      },
      {
        Effect   = "Allow"
        Action   = ["execute-api:ManageConnections"]
        Resource = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${aws_apigatewayv2_api.chat.id}/*/POST/@connections/*"
      },
    ]
  })
}

resource "aws_lambda_function" "get_history" {
  function_name = "${var.project_name}-get-history"
  role          = aws_iam_role.get_history.arn
  handler       = "src/getHistory.handler"
  runtime       = "nodejs20.x"
  timeout       = 10

  filename         = data.archive_file.backend.output_path
  source_code_hash = data.archive_file.backend.output_base64sha256

  environment {
    variables = {
      MESSAGES_TABLE = aws_dynamodb_table.messages.name
    }
  }

  depends_on = [aws_cloudwatch_log_group.get_history]
}
