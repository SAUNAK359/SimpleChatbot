const responses = [
  { match: /hello|hi|hey/i, reply: 'Hello! How can I help you today?' },
  { match: /name/i, reply: 'I am SimpleChatbot, running through AutoForge CI.' },
  { match: /bye|goodbye/i, reply: 'Goodbye!' },
];

function replyTo(message) {
  const text = String(message ?? '').trim();
  if (!text) return 'Please enter a message.';

  const found = responses.find((item) => item.match.test(text));
  return found ? found.reply : `You said: ${text}`;
}

module.exports = { replyTo };
