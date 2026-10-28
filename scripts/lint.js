const fs = require('fs');
const path = require('path');

const files = [
  'src/chatbot.js',
  'scripts/test.js',
  'scripts/lint.js',
  'scripts/build.js',
];

let failed = false;
for (const file of files) {
  const full = path.join(process.cwd(), file);
  if (!fs.existsSync(full)) {
    console.error(`Missing required file: ${file}`);
    failed = true;
    continue;
  }
  const text = fs.readFileSync(full, 'utf8');
  if (text.includes('\t')) {
    console.error(`Tab character found in ${file}`);
    failed = true;
  }
  if (/\s+$/m.test(text)) {
    console.error(`Trailing whitespace found in ${file}`);
    failed = true;
  }
}

if (failed) process.exit(1);
console.log('Lint checks passed.');
