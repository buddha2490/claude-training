#!/usr/bin/env node
/**
 * server.js — CDISC RAG MCP server
 *
 * Exposes FTS5 keyword search over rag.db to Claude Code via the MCP protocol.
 * Uses Node.js built-in node:sqlite — no Python, no native compilation,
 * no ML model download. Just Node.js (already required for Claude Code).
 *
 * Registered via .mcp.json in the repo root. DB path resolves relative to
 * this file so the server works wherever the repo is cloned.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { DatabaseSync } from "node:sqlite";
import { z } from "zod";
import { fileURLToPath } from "url";
import path from "path";

// Resolve rag.db relative to this file: rag/server.js → rag/rag.db
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DB_PATH = process.env.DB_PATH ?? path.join(__dirname, "rag.db");

const db = new DatabaseSync(DB_PATH, { readOnly: true });

// ---------------------------------------------------------------------------
// FTS5 query builder
// Strips punctuation, removes stop words, wraps each token in double quotes
// so that identifiers like AEDECOD are matched literally (not as FTS5 syntax).
// ---------------------------------------------------------------------------

const STOP_WORDS = new Set([
  "a", "an", "the", "and", "or", "is", "are", "was", "were", "be",
  "been", "being", "have", "has", "had", "do", "does", "did", "will",
  "would", "should", "could", "may", "might", "shall", "can", "need",
  "what", "which", "who", "how", "when", "where", "why", "that", "this",
  "these", "those", "it", "its", "of", "in", "on", "at", "to", "for",
  "with", "by", "from", "up", "about", "into", "through", "during",
  "before", "after", "above", "below", "between", "each", "both",
  "i", "me", "my", "we", "our", "you", "your", "he", "she", "they",
  "them", "their", "all", "any", "not", "no", "so", "as", "if",
]);

function ftsEscape(query) {
  const tokens = query
    .split(/\s+/)
    .map(tok => tok.replace(/[()\"'*^:,.?!;]/g, "").trim())
    .filter(tok => tok && !STOP_WORDS.has(tok.toLowerCase()))
    .map(tok => `"${tok}"`);
  return tokens.length ? tokens.join(" ") : '""';
}

// ---------------------------------------------------------------------------
// Prepared statements (compiled once at startup for performance)
// chunks_fts.rowid maps to chunks.id (INTEGER PRIMARY KEY)
// ---------------------------------------------------------------------------

const stmtAll = db.prepare(`
  SELECT c.source, c.title, c.content, bm25(chunks_fts) AS score
  FROM   chunks_fts
  JOIN   chunks c ON c.id = chunks_fts.rowid
  WHERE  chunks_fts MATCH ?
  ORDER  BY score
  LIMIT  ?
`);

const stmtFiltered = db.prepare(`
  SELECT c.source, c.title, c.content, bm25(chunks_fts) AS score
  FROM   chunks_fts
  JOIN   chunks c ON c.id = chunks_fts.rowid
  WHERE  chunks_fts MATCH ?
    AND  c.source = ?
  ORDER  BY score
  LIMIT  ?
`);

// ---------------------------------------------------------------------------
// MCP server
// ---------------------------------------------------------------------------

const server = new McpServer({ name: "cdisc-rag", version: "1.0.0" });

server.tool(
  "rag_search",
  {
    query: z.string()
      .describe(
        "Natural language or keyword query. Examples: " +
        "'valid values for AEOUT', 'SDTM timing variables', " +
        "'ADaM ADAE required columns', 'MedDRA hierarchy'"
      ),
    limit: z.number().int().min(1).max(50).optional().default(10)
      .describe("Maximum results to return (default 10)"),
    source: z.string().optional()
      .describe("Optional source filter. Currently available: cdisc-ct"),
  },
  async ({ query, limit, source }) => {
    let rows;
    try {
      const ftsQuery = ftsEscape(query);
      rows = source
        ? stmtFiltered.all(ftsQuery, source, limit)
        : stmtAll.all(ftsQuery, limit);
    } catch (err) {
      return { content: [{ type: "text", text: `Search error: ${err.message}` }] };
    }

    if (!rows.length) {
      return { content: [{ type: "text", text: "No results found." }] };
    }

    const text = rows
      .map(r =>
        `## ${r.title}\n**Source:** ${r.source} | **Score:** ${r.score.toFixed(4)}\n\n${r.content}`
      )
      .join("\n\n---\n\n");

    return { content: [{ type: "text", text }] };
  }
);

// ---------------------------------------------------------------------------
// Start
// ---------------------------------------------------------------------------

const transport = new StdioServerTransport();
await server.connect(transport);
