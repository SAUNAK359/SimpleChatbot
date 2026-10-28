const assert = require('assert');
const { replyTo } = require('../src/chatbot');

assert.strictEqual(replyTo('hello'), 'Hello! How can I help you today?');
assert.strictEqual(replyTo('what is your name?'), 'I am SimpleChatbot, running through AutoForge CI.');
assert.strictEqual(replyTo('bye'), 'Goodbye!');
assert.strictEqual(replyTo(''), 'Please enter a message.');
assert.strictEqual(replyTo('testing'), 'You said: testing');

console.log('All chatbot tests passed.');
