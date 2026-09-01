#!/usr/bin/env node

import { mkdir, readdir, readFile, writeFile } from "node:fs/promises";
import { dirname, extname, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import ts from "typescript";

const appRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const repoRoot = resolve(appRoot, "../..");
const srcRoot = resolve(appRoot, "src");
const outputPath = resolve(repoRoot, "docs/web/evidence/ionic-fidelity/copy-inventory.json");
const userFacingAttributes = new Set([
  "alt",
  "aria-description",
  "aria-label",
  "helperText",
  "label",
  "placeholder",
  "title",
]);

async function sourceFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const nested = await Promise.all(
    entries.map(async (entry) => {
      const path = resolve(directory, entry.name);
      if (entry.isDirectory()) return sourceFiles(path);
      if (!entry.isFile()) return [];
      if (![".ts", ".tsx"].includes(extname(path))) return [];
      if (path.endsWith(".test.ts") || path.endsWith(".test.tsx")) return [];
      return [path];
    }),
  );
  return nested.flat().sort();
}

function normalize(value) {
  return value.replace(/\s+/g, " ").trim();
}

function literalText(node, constants) {
  if (ts.isStringLiteralLike(node)) return [node.text];
  if (ts.isIdentifier(node) && constants.has(node.text)) return [constants.get(node.text)];
  if (ts.isParenthesizedExpression(node)) return literalText(node.expression, constants);
  if (ts.isConditionalExpression(node)) {
    return [
      ...literalText(node.whenTrue, constants),
      ...literalText(node.whenFalse, constants),
    ];
  }
  if (ts.isBinaryExpression(node)) {
    return [...literalText(node.left, constants), ...literalText(node.right, constants)];
  }
  if (ts.isTemplateExpression(node)) {
    const source = node.getText();
    return [normalize(source.slice(1, -1).replace(/\$\{[^}]+\}/g, "{value}"))];
  }
  return [];
}

const surfaceStrings = [];
const allStringLiterals = [];

for (const path of await sourceFiles(srcRoot)) {
  const source = await readFile(path, "utf8");
  const file = ts.createSourceFile(path, source, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
  const displayPath = relative(repoRoot, path);
  const constants = new Map();

  function location(node) {
    return file.getLineAndCharacterOfPosition(node.getStart(file)).line + 1;
  }

  function addSurface(node, context, value) {
    const text = normalize(value);
    if (!text) return;
    surfaceStrings.push({ file: displayPath, line: location(node), context, text });
  }

  function collectConstants(node) {
    if (
      ts.isVariableDeclaration(node) &&
      ts.isIdentifier(node.name) &&
      node.initializer &&
      ts.isStringLiteralLike(node.initializer)
    ) {
      constants.set(node.name.text, node.initializer.text);
    }
    ts.forEachChild(node, collectConstants);
  }
  collectConstants(file);

  function visit(node) {
    if (ts.isStringLiteralLike(node) && !ts.isImportDeclaration(node.parent)) {
      const text = normalize(node.text);
      if (text) {
        allStringLiterals.push({
          file: displayPath,
          line: location(node),
          syntax: ts.SyntaxKind[node.parent.kind],
          text,
        });
      }
    }

    if (ts.isJsxText(node)) addSurface(node, "jsx-text", node.text);

    if (ts.isJsxAttribute(node) && userFacingAttributes.has(node.name.text)) {
      const initializer = node.initializer;
      if (initializer && ts.isStringLiteral(initializer)) {
        addSurface(initializer, "jsx-attribute:" + node.name.text, initializer.text);
      } else if (initializer && ts.isJsxExpression(initializer) && initializer.expression) {
        for (const value of literalText(initializer.expression, constants)) {
          addSurface(initializer.expression, "jsx-attribute:" + node.name.text, value);
        }
      }
    }

    if (
      ts.isJsxExpression(node) &&
      node.expression &&
      (ts.isJsxElement(node.parent) || ts.isJsxFragment(node.parent))
    ) {
      for (const value of literalText(node.expression, constants)) {
        addSurface(node.expression, "jsx-expression", value);
      }
    }

    ts.forEachChild(node, visit);
  }
  visit(file);
}

function dedupe(items) {
  const seen = new Set();
  return items.filter((item) => {
    const key = JSON.stringify(item);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

const inventory = {
  scope: "apps/web-ionic/src/**/*.{ts,tsx}, excluding tests",
  method: {
    surfaceStrings:
      "JSX text, user-facing JSX attributes, direct literal/conditional JSX expressions, and local string constants referenced directly by JSX.",
    allStringLiterals:
      "An exhaustive superset of non-import string literals for manual false-positive filtering and indirect-copy checks.",
  },
  surfaceStrings: dedupe(surfaceStrings),
  allStringLiterals: dedupe(allStringLiterals),
};

await mkdir(dirname(outputPath), { recursive: true });
await writeFile(outputPath, JSON.stringify(inventory, null, 2) + "\n", "utf8");
console.log(
  "Wrote " +
    relative(repoRoot, outputPath) +
    " (" +
    inventory.surfaceStrings.length +
    " surface strings; " +
    inventory.allStringLiterals.length +
    " total string literals).",
);
