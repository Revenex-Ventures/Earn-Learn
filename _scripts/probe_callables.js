"use strict";
const fs = require("fs");
const path = require("path");
const root = "D:\\VS Code\\EarnAndLearn";
const target = path.join(root, "lib", "data", "firebase", "attendance_gateway.dart");
if (!fs.existsSync(target)) {
  console.error("gateway not found at " + target);
  process.exit(2);
}
const src = fs.readFileSync(target, "utf8");
const re = /httpsCallable\s*\(\s*['"]([A-Za-z0-9_.]+)['"]/g;
const names = [];
let m;
while ((m = re.exec(src))) names.push(m[1]);
const uniq = [...new Set(names)];
console.log("httpsCallable names referenced:" + (uniq.length ? "" : " NONE"));
for (const n of uniq) console.log("  " + n);
console.log("count=" + uniq.length);
