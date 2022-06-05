#! /usr/bin/env node
let body = require('child_process').execSync('imbac -p make_cuts.imba');
require('fs').writeFileSync('make_cuts', ("#! /usr/bin/env node\n\n" + body));
