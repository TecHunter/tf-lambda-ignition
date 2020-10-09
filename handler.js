'use strict';

const content = require('./content.json');

exports.handler = (event, context, callback) => {
    callback(null,
        {
            "statusCode": 200,
            "headers": {
                "Cache-Control": "no-cache, max-age=0"
            },
            "body": JSON.stringify(content),
            "isBase64Encoded": false
        });
};