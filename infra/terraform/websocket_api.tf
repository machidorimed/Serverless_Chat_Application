# ------------------------------------------------------------#
#  Amazon API gateway(Websocket API)
# ------------------------------------------------------------#

resource "aws_apigatewayv2_api" "chat" {
  name                       = "${var.project_name}-websocket-api"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action" # 送られてきたメッセージ本文(JSON)の中の`action`というキーの値を見て、ルーティングを決める
}

# ---------- $connect ----------

resource "aws_apigatewayv2_integration" "connect" {
  api_id = aws_apigatewayv2_api.chat.id
  # API GatewayとLambdaの連携方式
  # リクエストを加工せずLambdaへ直接譲渡
  integration_type = "AWS_PROXY"
  # どのLambda関数に処理を委譲するかの指定
  integration_uri = aws_lambda_function.connect.invoke_arn
  # リクエストボディをどう扱うかの指定。
  # バイナリデータではなくテキスト(JSON文字列)として扱うことを明示しています.
  content_handling_strategy = "CONVERT_TO_TEXT"
}

resource "aws_apigatewayv2_route" "connect" {
  api_id    = aws_apigatewayv2_api.chat.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.connect.id}"
}

resource "aws_lambda_permission" "connect" {
  # Lambdaファンクションに付与するAPIGatewayが
  # 呼び出すことを許可するリソースベースのポリシー
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.connect.function_name
  # 誰に呼び出す権限を与えるか
  # principalとsource_arnから明示
  principal  = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.chat.execution_arn}/*/$connect"
}

# ---------- $disconnect ----------

resource "aws_apigatewayv2_integration" "disconnect" {
  api_id                    = aws_apigatewayv2_api.chat.id
  integration_type          = "AWS_PROXY"
  integration_uri           = aws_lambda_function.disconnect.invoke_arn
  content_handling_strategy = "CONVERT_TO_TEXT"
}

resource "aws_apigatewayv2_route" "disconnect" {
  api_id    = aws_apigatewayv2_api.chat.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.disconnect.id}"
}

resource "aws_lambda_permission" "disconnect" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.disconnect.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.chat.execution_arn}/*/$disconnect"
}

# ---------- sendMessage ----------

resource "aws_apigatewayv2_integration" "send_message" {
  api_id                    = aws_apigatewayv2_api.chat.id
  integration_type          = "AWS_PROXY"
  integration_uri           = aws_lambda_function.send_message.invoke_arn
  content_handling_strategy = "CONVERT_TO_TEXT"
}

resource "aws_apigatewayv2_route" "send_message" {
  api_id    = aws_apigatewayv2_api.chat.id
  route_key = "sendMessage"
  target    = "integrations/${aws_apigatewayv2_integration.send_message.id}"
}

resource "aws_lambda_permission" "send_message" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.send_message.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.chat.execution_arn}/*/sendMessage"
}

# ---------- getHistory ----------

resource "aws_apigatewayv2_integration" "get_history" {
  api_id                    = aws_apigatewayv2_api.chat.id
  integration_type          = "AWS_PROXY"
  integration_uri           = aws_lambda_function.get_history.invoke_arn
  content_handling_strategy = "CONVERT_TO_TEXT"
}

resource "aws_apigatewayv2_route" "get_history" {
  api_id    = aws_apigatewayv2_api.chat.id
  route_key = "getHistory"
  target    = "integrations/${aws_apigatewayv2_integration.get_history.id}"
}

resource "aws_lambda_permission" "get_history" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_history.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.chat.execution_arn}/*/getHistory"
}

# ---------- $default  ----------

resource "aws_apigatewayv2_route" "default" {
  # 登録されていない未知のactionを受けた場合のフォールバック
  # 400 Bad Requestを返すだけなのでLambda連携なし
  api_id    = aws_apigatewayv2_api.chat.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.send_message.id}"
}

# ---------- Stage ----------
# APIをブラウザで公開するためのリソース

resource "aws_apigatewayv2_stage" "prod" {
  api_id = aws_apigatewayv2_api.chat.id
  name   = "prod"
  # 設定を変更した際、手動でデプロイ操作をしなくても
  # 自動的にこのステージへ反映する設定
  auto_deploy = true

  # スロットリング(流量制限)設定。
  # 意図しない高額課金を防ぐ安全弁として、全ルート共通の上限を設定している。
  default_route_settings {
    throttling_burst_limit = 50  # 瞬間的なアクセス集中に対して、一時的にどこまで許容するかの上限
    throttling_rate_limit  = 100 # 1秒あたり定常的に処理できるリクエスト数の上限(100 req/秒)
  }
}
