# ------------------------------------------------------------#
#  Amazon Cognito
# ------------------------------------------------------------#
resource "aws_cognito_user_pool" "this" {
  name = "${var.project_name}-user-pool"

  # メールアドレスをユーザー名として登録
  username_attributes = ["email"]
  # サインアップ時に、指定した属性の値を、
  # 確認コードを使って自動的に検証させる
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8     # 8文字以上
    require_lowercase = true  # 小文字を1文字以上含む
    require_numbers   = true  # 数字を1文字以上含む
    require_symbols   = false # 記号は必須にしない
    require_uppercase = true  # 大文字を1文字以上含む
  }

  account_recovery_setting {
    recovery_mechanism {
      # 『パスワードを忘れた』を選んだ場合、
      # 登録済みのメールアドレスに確認コード送付
      name     = "verified_email"
      priority = 1
    }
  }

  # 確認コードメールの件名・本文をカスタマイズ。
  # {####} はCognitoが実際の確認コードに自動置換する予約プレースホルダー。
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "【Bird Bath】確認コードのお知らせ"
    email_message        = <<-EOT
      チャットアプリ『Bird Bath』へようこそ。
      確認コードは {####} です。
    EOT
  }
}

resource "aws_cognito_user_pool_client" "spa" {
  name         = "${var.project_name}-spa-client"
  user_pool_id = aws_cognito_user_pool.this.id

  # クライアントシークレット(秘密鍵)の発行有無
  # SPAはクライアントシークレットを安全に保持できないため無効化
  generate_secret = false

  # 認証方式のホワイトリスト
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",      # SRP(Secure Remote Password)方式でのサインイン
    "ALLOW_REFRESH_TOKEN_AUTH", # リフレッシュトークンを使って新しいIDトークンを取得することを許可
  ]

  access_token_validity  = 60 # アクセストークンの有効期限（分）
  id_token_validity      = 60 # IDトークンの有効期限（分）
  refresh_token_validity = 30 # リフレッシュトークンの有効期限（日）

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # サインイン失敗時、いかなる状況でも『Incorrect username or password.』と返って来る
  prevent_user_existence_errors = "ENABLED"

  # ニックネーム読み取り設定
  # Cognitoの標準属性から実装。
  # 明示的に許可しないとSPAから読み書きできないため、必要な属性だけを列挙する。
  read_attributes  = ["email", "nickname"]
  write_attributes = ["email", "nickname"]
}
