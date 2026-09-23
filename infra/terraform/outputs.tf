output "websocket_url" {
  description = "フロントエンドが接続するWebSocket URL(wss://)"
  value       = "${aws_apigatewayv2_api.chat.api_endpoint}/${aws_apigatewayv2_stage.prod.name}"
}

output "user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.this.id
}

output "user_pool_client_id" {
  description = "Cognito User Pool Client ID(SPA用、シークレットなし)"
  value       = aws_cognito_user_pool_client.spa.id
}

output "cloudfront_domain" {
  description = "フロントエンドの公開URL"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "デプロイ後のキャッシュ無効化(invalidation)に使用するCloudFront Distribution ID"
  value       = aws_cloudfront_distribution.frontend.id
}

output "s3_bucket_name" {
  description = "フロントエンドの静的ファイルをアップロードするS3バケット名"
  value       = aws_s3_bucket.frontend.bucket
}

output "aws_region" {
  value = var.aws_region
}
