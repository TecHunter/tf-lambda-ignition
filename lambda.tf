data "template_file" "content" {
  template = file("${path.module}/${var.ignition_file}")
}

data "template_file" "handler" {
  template = file("${path.module}/handler.tpl")
}

data "archive_file" "lambda_zip" {
  type          = "zip"

  output_path   = "lambda_function.zip"
  source {
    content  = data.template_file.handler.rendered
    filename = "index.js"
  }
  source {
    content  = data.template_file.content.rendered
    filename = "content.json"
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
    
resource "aws_lambda_permission" "allow_gateway" {
  statement_id  = "AllowExecutionFromGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda.function_name
  principal     = "apigateway.amazonaws.com"
}

###### IAM ROLE
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

###################### API #######################

resource "aws_api_gateway_rest_api" "ApiGateway" {
  name = var.api_name
  description = var.api_description
}

#### METHODS
# GET /
resource "aws_api_gateway_method" "get-root" {
   rest_api_id   = aws_api_gateway_rest_api.ApiGateway.id
   resource_id   = aws_api_gateway_rest_api.ApiGateway.root_resource_id
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
  http_method = aws_api_gateway_method.get-ignition.http_method

  type = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.root_lambda.invoke_arn
}


resource "aws_api_gateway_integration" "root" {
  rest_api_id = aws_api_gateway_rest_api.ApiGateway.id
  resource_id = aws_api_gateway_rest_api.ApiGateway.root_resource_id
  http_method = aws_api_gateway_method.get-root.http_method

  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.root_lambda.invoke_arn
}

resource "aws_api_gateway_method_response" "root_response_200" {
  rest_api_id = aws_api_gateway_rest_api.ApiGateway.id
  resource_id = aws_api_gateway_rest_api.ApiGateway.root_resource_id
  http_method = aws_api_gateway_method.get-root.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "root" {
  rest_api_id = aws_api_gateway_rest_api.ApiGateway.id
  resource_id = aws_api_gateway_rest_api.ApiGateway.root_resource_id
  http_method = aws_api_gateway_method.get-root.http_method
  status_code = aws_api_gateway_method_response.root_response_200.status_code

}


resource "aws_api_gateway_method_response" "ignition_response_200" {
  rest_api_id = aws_api_gateway_rest_api.ApiGateway.id
  resource_id = aws_api_gateway_resource.ignition.id
  http_method = aws_api_gateway_method.get-ignition.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "ignition" {
  rest_api_id = aws_api_gateway_rest_api.ApiGateway.id
  resource_id = aws_api_gateway_resource.ignition.id
  http_method = aws_api_gateway_method.get-ignition.http_method
  status_code = aws_api_gateway_method_response.ignition_response_200.status_code

}

resource "aws_api_gateway_deployment" "ApiDeployment" {
  depends_on = [aws_api_gateway_integration.ignition,aws_api_gateway_integration.root]
  rest_api_id = aws_api_gateway_rest_api.ApiGateway.id

  stage_name = var.stage
  lifecycle {
    create_before_destroy = true
  }
}
