resource "aws_api_gateway_rest_api" "ApiGateway" {
  name = var.api_name
  description = var.api_description
}

resource "aws_api_gateway_resource" "ignition" {
  rest_api_id = aws_api_gateway_rest_api.ApiGateway.id
  parent_id = aws_api_gateway_rest_api.ApiGateway.root_resource_id
}

resource "aws_api_gateway_method" "get-ignition" {
  rest_api_id = aws_api_gateway_rest_api.ApiGateway.id
  resource_id = aws_api_gateway_resource.ignition.id

  http_method = "GET"
  authorization = "NONE"
}

data "template_file" "handler"{
    template = "${file("${path.module}/handler.tpl")}"
    vars {
        content = "${file("${path.module}/example.fcc")}"
    }
}

data "archive_file" "lambda_zip" {
    type          = "zip"
    source_file   = "index.js"
    output_path   = "lambda_function.zip"
}

resource "aws_lambda_function" "root_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "get-ignition"
  role             = aws_iam_role.iam_for_lambda_tf.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "nodejs12.x"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
      actions= ["sts:AssumeRole"]
      principals {
          type="Service"
          identifiers=["lambda.amazonaws.com"]
      }
      effect= "Allow"
  }
}

resource "aws_iam_role" "iam_for_lambda_tf" {
  name = "iam_for_lambda_tf"

  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_api_gateway_integration" "ApiProxyIntegration" {
  rest_api_id = aws_api_gateway_rest_api.ApiGateway.id
  resource_id = aws_api_gateway_resource.ignition.id
  http_method = aws_api_gateway_method.get-ignition.http_method

  type = "HTTP_PROXY"
  integration_http_method = "GET"
  uri                     = aws_lambda_function.root_lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "ApiDeployment" {
  depends_on = [
    aws_api_gateway_integration.ApiProxyIntegration]
  rest_api_id = aws_api_gateway_rest_api.ApiGateway.id

  stage_name = var.stage
  lifecycle {
    create_before_destroy = true
  }
}