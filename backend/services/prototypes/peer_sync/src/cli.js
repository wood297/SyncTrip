// One phone, one terminal.

import readline from 'node:readline';
import { Replica } from './replica.js';
import { Link } from './net.js';

const name = process.argv[2];
if (!name) {
  console.error('usage: node src/cli.js <name>');
  process.exit(1);
}

const r = new Replica(name);
const link = new Link(r, () => draw());

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  prompt: `${name}> `,
});

function view() {
  const flagged = new Set(r.conflicts().map(c => c.actId));
  const acts = r.state()
    .filter(a => !a.dropped || flagged.has(a.id))
    .sort((a, b) => a.time.localeCompare(b.time));

  let out = `\n[${name}] ${link.online ? 'online' : 'OFFLINE'}`
    + `  peers: ${link.peers().join(', ') || 'none'}`
    + `  ops: ${r.ops.length}\n`;

  if (!acts.length) out += '  (empty)\n';
  for (const a of acts) {
    const mark = flagged.has(a.id) ? '!' : a.dropped ? 'x' : ' ';
    out += ` ${mark} ${a.id}  ${a.time.padEnd(6)} ${a.place.padEnd(12)} ${a.title}\n`;
  }

  const cf = r.conflicts();
  if (cf.length) {
    out += `\n  needs a group decision (${cf.length}):\n`;
    for (const c of cf) out += `    ${c.actId}  ${c.reason}\n`;
  }
  return out;
}

function draw() {
  console.log(view());
  rl.prompt(true);
}

const HELP = `
  add <time> <place> <title...>     add an activity
  set <id> <field> <value...>       field is time, place or title
  rm <id>                           drop an activity
  resolve <id> keep|drop            settle a flagged disagreement
  show                              print the timeline
  offline | online                  simulate leaving and re-entering range
  quit
`;

rl.on('line', line => {
  const [cmd, ...rest] = line.trim().split(/\s+/);
  try {
    switch (cmd) {
      case '': break;
      case 'add': link.push([r.add(rest[0], rest[1], rest.slice(2).join(' '))]); break;
      case 'set': link.push([r.set(rest[0], rest[1], rest.slice(2).join(' '))]); break;
      case 'rm': link.push([r.remove(rest[0])]); break;
      case 'resolve': link.push([r.resolve(rest[0], rest[1])]); break;
      case 'offline': link.setOnline(false); break;
      case 'online': link.setOnline(true); break;
      case 'show': break;
      case 'quit': process.exit(0);
      default: console.log(HELP); rl.prompt(); return;
    }
  } catch (e) {
    console.log('  ' + e.message);
  }
  draw();
});

console.log(HELP);
draw();
