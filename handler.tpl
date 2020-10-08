'use strict';

const content = require('./content.json');

exports.handler = (event, context, callback) => {
    callback(null, JSON.stringify(content));
};