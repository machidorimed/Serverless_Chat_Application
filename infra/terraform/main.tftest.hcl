# S3バケットのパブリックアクセス設定がブロックされているか
run "s3_public_access_is_fully_blocked" {
  command = plan

  assert {
    condition     = aws_s3_bucket_public_access_block.frontend.block_public_acls == true
    error_message = "S3バケットのblock_public_aclsがtrueではありません"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.frontend.block_public_policy == true
    error_message = "S3バケットのblock_public_policyがtrueではありません"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.frontend.ignore_public_acls == true
    error_message = "S3バケットのignore_public_aclsがtrueではありません"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.frontend.restrict_public_buckets == true
    error_message = "S3バケットのrestrict_public_bucketsがtrueではありません"
  }
}

# DynamoDB/S3の保存時暗号化が有効なままか
run "encryption_at_rest_is_enabled" {
  command = plan

  assert {
    condition     = aws_dynamodb_table.connections.server_side_encryption[0].enabled == true
    error_message = "Connectionsテーブルの保存時暗号化が無効です"
  }

  assert {
    condition     = aws_dynamodb_table.messages.server_side_encryption[0].enabled == true
    error_message = "Messagesテーブルの保存時暗号化が無効です"
  }

  assert {
    condition = anytrue([
      for r in aws_s3_bucket_server_side_encryption_configuration.frontend.rule : anytrue([
        for d in r.apply_server_side_encryption_by_default : d.sse_algorithm == "AES256"
      ])
    ])
    error_message = "S3バケットの保存時暗号化(AES256)が設定されていません"
  }
}

# Cognitoのパスワードポリシーが弱くなっていないか
run "cognito_password_policy_is_not_weakened" {
  command = plan

  assert {
    condition     = aws_cognito_user_pool.this.password_policy[0].minimum_length >= 8
    error_message = "パスワードの最小文字数が8文字未満になっています"
  }

  assert {
    condition     = aws_cognito_user_pool.this.password_policy[0].require_lowercase == true
    error_message = "パスワードポリシーのrequire_lowercaseがfalseになっています"
  }

  assert {
    condition     = aws_cognito_user_pool.this.password_policy[0].require_numbers == true
    error_message = "パスワードポリシーのrequire_numbersがfalseになっています"
  }

  assert {
    condition     = aws_cognito_user_pool.this.password_policy[0].require_uppercase == true
    error_message = "パスワードポリシーのrequire_uppercaseがfalseになっています"
  }
}

# CloudFrontがHTTPSを強制しているか
run "cloudfront_enforces_https" {
  command = plan

  assert {
    condition     = aws_cloudfront_distribution.frontend.default_cache_behavior[0].viewer_protocol_policy == "redirect-to-https"
    error_message = "CloudFrontがHTTPSを強制する設定(redirect-to-https)になっていません"
  }
}

# CognitoのSPA用クライアントにシークレットが発行されていないか
run "cognito_spa_client_has_no_secret" {
  command = plan

  assert {
    condition     = aws_cognito_user_pool_client.spa.generate_secret == false
    error_message = "SPA用Cognitoクライアントにシークレットが発行される設定になっています"
  }
}

# ログ保有期間の確認
run "cloudwatch_log_retention_is_7_days" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_group.connect.retention_in_days == 7
    error_message = "connect_Lambda関数のCloudWatch Logsの保持日数が不一致"
  }

  assert {
    condition     = aws_cloudwatch_log_group.disconnect.retention_in_days == 7
    error_message = "disconnect_Lambda関数のCloudWatch Logsの保持日数が不一致"
  }

  assert {
    condition     = aws_cloudwatch_log_group.send_message.retention_in_days == 7
    error_message = "send_message_Lambda関数のCloudWatch Logsの保持日数が不一致"
  }

  assert {
    condition     = aws_cloudwatch_log_group.get_history.retention_in_days == 7
    error_message = "get_history_Lambda関数のCloudWatch Logsの保持日数が不一致"
  }
}
