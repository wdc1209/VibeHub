import { evaluateRoute } from "./routingRules.js";
import { routeCases } from "./routeCases.js";

let failed = 0;

for (const testCase of routeCases) {
  const result = evaluateRoute(testCase.text, testCase.context || {});
  const ok = result.mode === testCase.expected;
  const status = ok ? "PASS" : "FAIL";
  console.log(
    `${status}  expected=${testCase.expected} actual=${result.mode}  text=${JSON.stringify(testCase.text)}`
  );
  if (!ok) {
    failed += 1;
    console.log(`      note=${testCase.note}`);
    console.log(`      reason=${result.reason}`);
    console.log(`      triggers=${(result.triggers || []).join(",")}`);
  }
}

if (failed > 0) {
  console.error(`\n${failed} route case(s) failed.`);
  process.exit(1);
}

console.log(`\nAll ${routeCases.length} route cases passed.`);
