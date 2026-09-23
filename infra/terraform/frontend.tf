# ------------------------------------------------------------#
#  Amazon S3
# ------------------------------------------------------------#
resource "random_id" "bucket_suffix" {
  # S3バケット名にランダムな値を追加。
  byte_length = 4
}

resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-frontend-${random_id.bucket_suffix.hex}"
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  # S3暗号化(SSE-S3)
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_cloudfront_origin_access_control" "frontend" {
  # S3　OACのビヘイビア設定
  # 特定のCloudFrontディストリビューションARNから送られてきた、
  # SigV4署名付きリクエストだけ`s3:GetObject`を許可する
  name                              = "${var.project_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ------------------------------------------------------------#
#  Amazon CloudFront
# ------------------------------------------------------------#

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_200" # 北米/欧州/アジアのみでコストを抑える

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "s3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"] # ブラウザからCloudFrontへ許可するHTTPメソッド
    cached_methods         = ["GET", "HEAD"] # 上記のうち、実際にキャッシュ対象とするメソッド
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https" # HTTPでアクセスされた場合、自動的にHTTPSへリダイレクトする設定。
    compress               = true

    forwarded_values {
      # オリジン(S3)へリクエストを転送する際、クエリパラメータや
      # cookieなどの情報を送らない。
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  # SPAのクライアントサイドルーティング用に404/403をindex.htmlへフォールバックさせる
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  # 特定の国・地域からのアクセスを制限しない
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  # HTTPS通信に使うSSL/TLS証明書の指定
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

data "aws_iam_policy_document" "frontend_bucket_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadOnly"
    effect = "Allow"

    # CloudFrontディストリビューションに上記S3バケットの読み取り権限を付与
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    # 条件は上記のCloudFrontディストリビューションに限定する
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.frontend.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_bucket_policy.json
}
