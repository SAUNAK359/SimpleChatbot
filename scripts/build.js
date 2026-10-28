const fs = require('fs');
const path = require('path');

const dist = path.join(process.cwd(), 'dist');
fs.mkdirSync(dist, { recursive: true });

const source = fs.readFileSync(path.join(process.cwd(), 'src/chatbot.js'), 'utf8');
const banner = '// AutoForge SimpleChatbot build artifact\n';
fs.writeFileSync(path.join(dist, 'chatbot.js'), banner + source, 'utf8');
fs.writeFileSync(
  path.join(dist, 'build-info.json'),
  JSON.stringify({ builtBy: 'AutoForge', artifact: 'dist/chatbot.js' }, null, 2),
  'utf8'
);

console.log('Build completed: dist/chatbot.js');
