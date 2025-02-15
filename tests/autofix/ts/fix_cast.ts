// Regression test for https://github.com/returntocorp/semgrep/issues/6233. The
// root cause is that parentheses were not included as part of the location of a
// cast node, so the metavariable location in cases like this includes on paren
// and not the other.

// MATCH:
1 + (x as Foo).bar
