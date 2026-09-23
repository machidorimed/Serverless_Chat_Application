# ------------------------------------------------------------#
#  Amazon DynamoDB
# ------------------------------------------------------------#
resource "aws_dynamodb_table" "connections" {
  # 現在つながっている人の一覧を表す一時的データを保存
  name         = "${var.project_name}-connections"
  billing_mode = "PAY_PER_REQUEST" # オンデマンドキャパシティ
  hash_key     = "connectionId"    #API Gateway接続時のID毎にパーティション作成

  attribute {
    # キーとして使う属性が文字列(`S` = String)であることを宣言
    name = "connectionId"
    type = "S"
  }

  server_side_encryption {
    enabled = true # 保存時暗号化(at-rest暗号化)を有効化
  }

  ttl {
    # $disconnectが呼ばれない異常切断時の保険として、TTLで自動削除。
    # API Gateway WebSocketの1接続あたりの最大生存時間は2時間なので、
    # それより長い３時間の猶予を持たせて backend/src/connect.js で ttl 属性(UNIX時刻)を設定。
    attribute_name = "ttl"
    enabled        = true
  }
}

resource "aws_dynamodb_table" "messages" {
  # 過去のチャット内容を保存
  name         = "${var.project_name}-messages"
  billing_mode = "PAY_PER_REQUEST" # オンデマンドキャパシティ
  hash_key     = "roomId"          # ルームID毎にパーティションを作成
  range_key    = "sortKey"         # パーティション（各ルーム）内のメッセージを時刻順に自動ソート（形式: "<timestampISO>#<messageId>"）

  attribute {
    name = "roomId"
    type = "S"
  }

  attribute {
    name = "sortKey"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }
}
