const fs = require('fs');
const path = require('path');

function checkFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const stack = [];
  let inSingleQuote = false;
  let inDoubleQuote = false;
  let inTripleSingleQuote = false;
  let inTripleDoubleQuote = false;
  let inSingleLineComment = false;
  let inMultiLineComment = false;
  let line = 1;
  let col = 1;

  for (let i = 0; i < content.length; i++) {
    const char = content[i];
    const nextChar = i + 1 < content.length ? content[i + 1] : '';
    const next2Char = i + 2 < content.length ? content[i + 2] : '';

    if (char === '\n') {
      line++;
      col = 1;
      inSingleLineComment = false;
      continue;
    } else {
      col++;
    }

    if (inSingleLineComment) continue;

    if (inMultiLineComment) {
      if (char === '*' && nextChar === '/') {
        inMultiLineComment = false;
        i++;
      }
      continue;
    }

    if (inTripleSingleQuote) {
      if (char === "'" && nextChar === "'" && next2Char === "'") {
        inTripleSingleQuote = false;
        i += 2;
      }
      continue;
    }

    if (inTripleDoubleQuote) {
      if (char === '"' && nextChar === '"' && next2Char === '"') {
        inTripleDoubleQuote = false;
        i += 2;
      }
      continue;
    }

    if (inSingleQuote) {
      if (char === '\\') {
        i++; // skip escaped char
      } else if (char === "'") {
        inSingleQuote = false;
      }
      continue;
    }

    if (inDoubleQuote) {
      if (char === '\\') {
        i++; // skip escaped char
      } else if (char === '"') {
        inDoubleQuote = false;
      }
      continue;
    }

    // Comment starts
    if (char === '/' && nextChar === '/') {
      inSingleLineComment = true;
      i++;
      continue;
    }
    if (char === '/' && nextChar === '*') {
      inMultiLineComment = true;
      i++;
      continue;
    }

    // String starts
    if (char === "'" && nextChar === "'" && next2Char === "'") {
      inTripleSingleQuote = true;
      i += 2;
      continue;
    }
    if (char === '"' && nextChar === '"' && next2Char === '"') {
      inTripleDoubleQuote = true;
      i += 2;
      continue;
    }
    if (char === "'") {
      inSingleQuote = true;
      continue;
    }
    if (char === '"') {
      inDoubleQuote = true;
      continue;
    }

    // Brackets
    if (char === '(' || char === '{' || char === '[') {
      stack.push({ char, line, col });
    } else if (char === ')' || char === '}' || char === ']') {
      if (stack.length === 0) {
        return { valid: false, error: `Unmatched closing '${char}' at line ${line}, col ${col}` };
      }
      const top = stack.pop();
      const expected = top.char === '(' ? ')' : top.char === '{' ? '}' : ']';
      if (char !== expected) {
        return { valid: false, error: `Mismatched closing '${char}', expected '${expected}' for '${top.char}' opened at line ${top.line}` };
      }
    }
  }

  if (stack.length > 0) {
    const unclosed = stack.pop();
    return { valid: false, error: `Unclosed '${unclosed.char}' opened at line ${unclosed.line}` };
  }
  if (inSingleQuote || inDoubleQuote || inTripleSingleQuote || inTripleDoubleQuote) {
    return { valid: false, error: `Unclosed string literal` };
  }
  if (inMultiLineComment) {
    return { valid: false, error: `Unclosed multi-line comment` };
  }

  return { valid: true };
}

const targetFiles = process.argv.slice(2);
let filesToCheck = [];

if (targetFiles.length > 0) {
  filesToCheck = targetFiles;
} else {
  // Default to modified files
  filesToCheck = [
    'lib/core/constants/app_constants.dart',
    'lib/providers/gasto_provider.dart',
    'lib/providers/settings_provider.dart',
    'lib/services/exchange_rate_service.dart',
    'test/providers/gasto_provider_rate_cache_test.dart',
    'test/providers/settings_provider_rate_cache_test.dart',
    'test/services/exchange_rate_service_cache_purge_test.dart'
  ];
}

console.log(`Checking syntax for ${filesToCheck.length} files...`);
let anyErrors = false;

filesToCheck.forEach(f => {
  if (!fs.existsSync(f)) {
    console.error(`File not found: ${f}`);
    anyErrors = true;
    return;
  }
  const res = checkFile(f);
  if (res.valid) {
    console.log(`[PASS] ${f}`);
  } else {
    console.error(`[FAIL] ${f}: ${res.error}`);
    anyErrors = true;
  }
});

if (anyErrors) {
  process.exit(1);
} else {
  console.log('ALL FILES BALANCED AND SYNTACTICALLY SOUND!');
}
