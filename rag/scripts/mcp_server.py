#!/usr/bin/env python3
"""
mcp_server.py — Python MCP server exposing RAG search and structured lookup
over rag.db (sqlite-vec + sentence-transformers).

Usage (via .mcp.json):
    python3 scripts/mcp_server.py

Environment:
    DB_PATH  Path to rag.db (default: <project_root>/rag.db)
"""

import os
import sqlite3
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
DB_PATH = Path(os.environ.get("DB_PATH", str(PROJECT_ROOT / "rag.db")))
MODEL_DIR = PROJECT_ROOT / "models" / "all-MiniLM-L6-v2"

sys.path.insert(0, str(PROJECT_ROOT / "scripts"))
from rag_query import query_hybrid as _query_hybrid

# Model download on first use (for rag_query lazy init)
def _ensure_model():
    if not MODEL_DIR.exists():
        print(f"Downloading model to {MODEL_DIR}...", file=sys.stderr, flush=True)
        try:
            from huggingface_hub import snapshot_download
            snapshot_download(
                repo_id="sentence-transformers/all-MiniLM-L6-v2",
                local_dir=str(MODEL_DIR),
            )
        except Exception as e:
            print(f"ERROR downloading model: {e}", file=sys.stderr)
            sys.exit(1)


# ---------------------------------------------------------------------------
# MCP server
# ---------------------------------------------------------------------------

from mcp.server.fastmcp import FastMCP

mcp = FastMCP("cdisc-rag")


@mcp.tool()
def query_documents(query: str, limit: int = 10, source: str = None) -> str:
    """Search the RAG index for documents relevant to the query.

    Args:
        query: Natural language search query.
        limit: Maximum number of results to return (default 10).
        source: Optional source filter — one of: cdisc-ct, icd-o-3, meddra,
                ctcae, ADS, ads-code, akasha, oneapp.  Omit to search all sources.
    """
    _ensure_model()
    rows = _query_hybrid(query, limit=limit, source=source, db_path=DB_PATH)

    if not rows:
        return "No results found."

    parts = []
    for src, title, content, score in rows:
        parts.append(
            f"## {title}\n**Source:** {src} | **Score:** {score:.4f}\n\n{content}"
        )
    return "\n\n---\n\n".join(parts)


@mcp.tool()
def lookup_variable(
    variable_name: str = None,
    tumor: str = None,
    section: str = None,
) -> str:
    """Look up variable definitions from the structured data dictionary.

    Covers two sources:
    - ADS (Analytical Datasets): tumor-type-specific variable specs.
    - OneApp NPM Data Dictionary: abstracted clinical variables with pivot
      table field names and value sets.

    Args:
        variable_name: Variable or element name to search for — display name
                       or pivot field name (e.g., 'age_dx', 'ca_dx_date',
                       'vital_status', 'drug_name').  Partial match supported.
        tumor: Source/tumor filter.  ADS values: Breast, Lung, Ovarian,
               Bladder, All Tumor ADS.  OneApp NPM value: npm.
               Omit to search all sources.
        section: Section or domain name filter (e.g., 'Key Variables',
                 'Medications', 'Vital Status', 'Genomics').
                 Partial match supported.
    """
    conn = sqlite3.connect(DB_PATH)

    conditions = []
    params = []
    if variable_name:
        conditions.append("(variable_name LIKE ? OR element_name LIKE ?)")
        params.extend([f"%{variable_name}%", f"%{variable_name}%"])
    if tumor:
        conditions.append("tumor LIKE ?")
        params.append(f"%{tumor}%")
    if section:
        conditions.append("section LIKE ?")
        params.append(f"%{section}%")

    where = ("WHERE " + " AND ".join(conditions)) if conditions else ""
    rows = conn.execute(
        f"""
        SELECT tumor, section, element_name, variable_name,
               type, values_list, description, enriched_only, data_source
        FROM variables {where}
        LIMIT 50
        """,
        params,
    ).fetchall()
    conn.close()

    if not rows:
        return "No matching variables found."

    parts = []
    for tumor_v, section_v, elem, var, typ, vals, desc, enriched, datasrc in rows:
        lines = [f"### {elem}" + (f" (`{var}`)" if var else "")]
        if tumor_v:
            lines.append(f"**Tumor:** {tumor_v}")
        if section_v:
            lines.append(f"**Section:** {section_v}")
        if typ:
            lines.append(f"**Type:** {typ}")
        if vals:
            lines.append(f"**Values:** {vals}")
        if desc:
            lines.append(f"**Description:** {desc}")
        if enriched:
            lines.append(f"**Enriched only:** {enriched}")
        if datasrc:
            lines.append(f"**Data source:** {datasrc}")
        parts.append("\n".join(lines))

    return "\n\n".join(parts)


if __name__ == "__main__":
    mcp.run()
