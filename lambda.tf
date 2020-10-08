data "template_file" "content" {
  template = file("${path.module}/example.fcc")
}

data "template_file" "handler" {
  template = templatefile(
        "${path.module}/handler.tpl",
        {
            content = data.template_file.content.rendered
        }
    )
}

data "archive_file" "lambda_zip" {
  type          = "zip"

  output_path   = "lambda_function.zip"
  source {
    content  = data.template_file.handler.rendered
    filename = "index.js"
  }
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


resource "aws_api_gateway_rest_api" "ApiGateway" {
  name = var.api_name
  description = var.api_description
}

#### METHODS
# GET /
resource "aws_api_gateway_method" "root" {
   rest_api_id   = aws_api_gateway_rest_api.ApiGateway.id
   resource_id   = aws_api_gateway_resource.root.id
   http_method   = "GET"
   authorization = "NONE"
}

resource "aws_api_gateway_resource" "ignition" {
  rest_api_id = aws_api_gateway_rest_api.ApiGateway.id
  parent_id = aws_api_gateway_rest_api.ApiGateway.root_resource_id
  path_part = "ignition"
}

resource "aws_api_gateway_method" "get-ignition" {
  rest_api_id = aws_api_gateway_rest_api.ApiGateway.id
  resource_id = aws_api_gateway_resource.ignition.id

  http_method = "GET"
  authorization = "NONE"
}

#############

resource "aws_api_gateway_integration" "ignition" {
  rest_api_id = aws_api_gateway_rest_api.ApiGateway.id
  resource_id = aws_api_gateway_resource.ignition.id
  http_method = aws_api_gateway_method.ignition.http_method

  type = "AWS"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.root_lambda.invoke_arn
}


resource "aws_api_gateway_integration" "root" {
  rest_api_id = aws_api_gateway_rest_api.ApiGateway.id
  resource_id = aws_api_gateway_rest_api.ApiGateway.root_resource_id
  http_method = aws_api_gateway_method.root.http_method

  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.root_lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "ApiDeployment" {
  depends_on = [aws_api_gateway_integration.ignition,aws_api_gateway_integration.root]
  rest_api_id = aws_api_gateway_rest_api.ApiGateway.id

  stage_name = var.stage
  lifecycle {
    create_before_destroy = true
  }
}