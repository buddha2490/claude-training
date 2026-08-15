#!/usr/bin/env python3
"""
rag_query.py — Shared hybrid search utility for rag.db.

Combines FTS5 BM25 keyword ranking with dense cosine-similarity vector search,
merged via Reciprocal Rank Fusion (RRF, k=60).

Exported:
    query_hybrid(query, limit, source, db_path, model_dir) -> list of (source, title, content, score)
    _open_db(db_path)
    _get_model(model_dir)
    _serialize_f32(vec)
"""

import sqlite3
import struct
from pathlib import Path

_PROJECT_ROOT = Path(__file__).parent.parent
DEFAULT_DB_PATH = _PROJECT_ROOT / "rag.db"
DEFAULT_MODEL_DIR = _PROJECT_ROOT / "models" / "all-MiniLM-L6-v2"

_model_cache = {}


def _get_model(model_dir: Path = None):
    model_dir = model_dir or DEFAULT_MODEL_DIR
    key = str(model_dir)
    if key not in _model_cache:
        from sentence_transformers import SentenceTransformer
        _model_cache[key] = SentenceTransformer(str(model_dir))
    return _model_cache[key]


def _open_db(db_path: Path = None):
    import sqlite_vec
    db_path = db_path or DEFAULT_DB_PATH
    conn = sqlite3.connect(str(db_path))
    conn.enable_load_extension(True)
    sqlite_vec.load(conn)
    conn.enable_load_extension(False)
    return conn


def _serialize_f32(vec):
    return struct.pack(f"{len(vec)}f", *vec)


# RRF constant — standard value; higher k de-emphasises rank differences
_RRF_K = 60


def query_hybrid(
    query: str,
    limit: int = 10,
    source: str = None,
    db_path: Path = None,
    model_dir: Path = None,
) -> list:
    """Hybrid BM25 + dense vector search with RRF fusion.

    Returns a list of (source, title, content, rrf_score) tuples, sorted by
    descending RRF score (higher = more relevant).  rrf_score is in (0, 1].

    Args:
        query:     Natural-language or keyword query string.
        limit:     Maximum results to return after fusion.
        source:    Optional source tag filter (e.g. "akasha", "oneapp").
        db_path:   Override default rag.db path.
        model_dir: Override default model directory.
    """
    model = _get_model(model_dir)
    vec = model.encode(query, normalize_embeddings=True).tolist()
    vec_bytes = _serialize_f32(vec)

    conn = _open_db(db_path)

    # How many candidates to fetch per leg before filtering/fusing.
    # Fetch extra so that source filtering doesn't starve the fusion.
    fetch_k = limit * 20 if source else limit * 4

    # --- Dense leg ---
    dense_rows = conn.execute(
        """
        SELECT c.id, c.source, c.title, c.content, v.distance
        FROM vec_chunks v
        JOIN chunks c ON c.id = v.rowid
        WHERE v.embedding MATCH ? AND k = ?
        ORDER BY v.distance
        """,
        (vec_bytes, fetch_k),
    ).fetchall()
    if source:
        dense_rows = [r for r in dense_rows if r[1] == source]

    # --- BM25 leg (FTS5) ---
    # FTS5 bm25() returns negative scores; ORDER BY bm25() ASC = best first.
    # Use the enhanced query syntax for phrase and prefix matching.
    try:
        # Escape FTS5 special chars so a bare variable name like "ca_dx_date"
        # doesn't cause a parse error.
        fts_query = _fts_escape(query)
        fts_rows = conn.execute(
            """
            SELECT c.id, c.source, c.title, c.content, bm25(chunks_fts) AS score
            FROM chunks_fts
            JOIN chunks c ON c.rowid = chunks_fts.rowid
            WHERE chunks_fts MATCH ?
            ORDER BY score
            """,
            (fts_query,),
        ).fetchall()
        if source:
            fts_rows = [r for r in fts_rows if r[1] == source]
        fts_rows = fts_rows[:fetch_k]
    except sqlite3.OperationalError:
        # FTS5 table missing (old db) or query parse error — fall back to dense only
        fts_rows = []

    conn.close()

    # --- RRF fusion ---
    scores: dict[int, float] = {}
    id_to_row: dict[int, tuple] = {}

    for rank, (row_id, src, title, content, _) in enumerate(dense_rows):
        scores[row_id] = scores.get(row_id, 0.0) + 1.0 / (_RRF_K + rank + 1)
        id_to_row[row_id] = (src, title, content)

    for rank, (row_id, src, title, content, _) in enumerate(fts_rows):
        scores[row_id] = scores.get(row_id, 0.0) + 1.0 / (_RRF_K + rank + 1)
        id_to_row[row_id] = (src, title, content)

    ranked = sorted(scores.items(), key=lambda x: x[1], reverse=True)

    results = []
    for row_id, rrf_score in ranked[:limit]:
        src, title, content = id_to_row[row_id]
        results.append((src, title, content, rrf_score))

    return results


_STOP_WORDS = frozenset({
    "a", "an", "the", "and", "or", "is", "are", "was", "were", "be",
    "been", "being", "have", "has", "had", "do", "does", "did", "will",
    "would", "should", "could", "may", "might", "shall", "can", "need",
    "what", "which", "who", "how", "when", "where", "why", "that", "this",
    "these", "those", "it", "its", "of", "in", "on", "at", "to", "for",
    "with", "by", "from", "up", "about", "into", "through", "during",
    "before", "after", "above", "below", "between", "each", "both",
    "i", "me", "my", "we", "our", "you", "your", "he", "she", "they",
    "them", "their", "all", "any", "not", "no", "so", "as", "if",
})


def _fts_escape(query: str) -> str:
    """Convert a free-text query to an FTS5-safe expression.

    Strategy: strip punctuation from tokens, drop English stop words, then
    join with implicit AND (FTS5 default).  Each content token is wrapped in
    double quotes so underscored identifiers like ca_dx_date are matched
    literally rather than triggering FTS5 prefix/column syntax.
    Stop-word filtering prevents common words absent from chunk content from
    causing FTS5 to return zero results.
    """
    tokens = query.split()
    safe = []
    for tok in tokens:
        # Strip FTS5 special chars and trailing punctuation
        tok = tok.strip('()"\'*^:,.?!;')
        if not tok:
            continue
        if tok.lower() in _STOP_WORDS:
            continue
        safe.append(f'"{tok}"')
    if not safe:
        return '""'
    return " ".join(safe)
