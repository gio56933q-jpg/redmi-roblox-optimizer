import { useState, useCallback } from "react";

const LETTERS = "abcdefghijklmnopqrstuvwxyz";
const MIDDLE = "abcdefghijklmnopqrstuvwxyz0123456789_.";

function isValid(name) {
  if (name.length !== 4) return false;
  if (!/^[a-z0-9._]+$/.test(name)) return false;
  if (/^[._]/.test(name) || /[._]$/.test(name)) return false;
  if (/[._]{2}/.test(name)) return false;
  return true;
}

function randomName() {
  let attempts = 0;
  while (attempts++ < 100) {
    const a = LETTERS[Math.floor(Math.random() * LETTERS.length)];
    const b = MIDDLE[Math.floor(Math.random() * MIDDLE.length)];
    const c = MIDDLE[Math.floor(Math.random() * MIDDLE.length)];
    const d = LETTERS[Math.floor(Math.random() * LETTERS.length)];
    const name = a + b + c + d;
    if (isValid(name)) return name;
  }
  return null;
}

function generateBatch(count = 30) {
  const results = new Set();
  while (results.size < count) {
    const n = randomName();
    if (n) results.add(n);
  }
  return [...results];
}

// Filters
const FILTERS = {
  all: () => true,
  "letters only": (n) => /^[a-z]+$/.test(n),
  "has numbers": (n) => /[0-9]/.test(n),
  "has symbols": (n) => /[._]/.test(n),
  "starts vowel": (n) => "aeiou".includes(n[0]),
  "ends vowel": (n) => "aeiou".includes(n[3]),
};

export default function App() {
  const [names, setNames] = useState(() => generateBatch(60));
  const [filter, setFilter] = useState("all");
  const [copied, setCopied] = useState(null);
  const [copiedAll, setCopiedAll] = useState(false);
  const [pinned, setPinned] = useState([]);
  const [customLen, setCustomLen] = useState(4);

  const filtered = names.filter(FILTERS[filter]);

  const regen = useCallback(() => setNames(generateBatch(60)), []);

  const copyOne = (name) => {
    navigator.clipboard.writeText(name);
    setCopied(name);
    setTimeout(() => setCopied(null), 1500);
  };

  const copyAll = () => {
    navigator.clipboard.writeText(filtered.join("\n"));
    setCopiedAll(true);
    setTimeout(() => setCopiedAll(false), 1500);
  };

  const pin = (name) => setPinned((p) => p.includes(name) ? p.filter(x => x !== name) : [...p, name]);

  return (
    <div style={{
      minHeight: "100vh",
      background: "#0d0f14",
      color: "#e2e8f0",
      fontFamily: "'Courier New', monospace",
    }}>
      {/* Header */}
      <div style={{
        background: "linear-gradient(135deg, #5865f2, #3b41c5)",
        padding: "22px 28px",
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        boxShadow: "0 4px 32px #5865f240",
      }}>
        <div>
          <div style={{ fontSize: "20px", fontWeight: "bold", letterSpacing: "3px" }}>
            USERNAME FORGE
          </div>
          <div style={{ fontSize: "11px", opacity: 0.65, letterSpacing: "2px", marginTop: "2px" }}>
            DISCORD 4-LETTER GENERATOR • VALID FORMAT GUARANTEED
          </div>
        </div>
        <button onClick={regen} style={{
          background: "rgba(255,255,255,0.15)",
          border: "1px solid rgba(255,255,255,0.25)",
          color: "white",
          padding: "10px 20px",
          borderRadius: "8px",
          fontFamily: "monospace",
          fontSize: "13px",
          cursor: "pointer",
          letterSpacing: "1px",
          transition: "all 0.15s",
        }}>
          ⟳ REGENERATE
        </button>
      </div>

      {/* Rules banner */}
      <div style={{
        background: "#111318",
        borderBottom: "1px solid #1e2330",
        padding: "10px 28px",
        display: "flex",
        gap: "20px",
        flexWrap: "wrap",
        fontSize: "11px",
        color: "#555",
        letterSpacing: "0.5px",
      }}>
        {[
          "✓ a–z, 0–9, _ and . allowed",
          "✓ Cannot start/end with . or _",
          "✓ No consecutive . or _",
          "✓ Lowercase only",
          "✓ Exactly 4 characters",
        ].map((r) => <span key={r} style={{ color: "#00ff8870" }}>{r}</span>)}
      </div>

      <div style={{ display: "flex", gap: 0, flex: 1 }}>
        {/* Left: filters + pinned */}
        <div style={{
          width: "200px",
          minWidth: "200px",
          background: "#111318",
          borderRight: "1px solid #1e2330",
          padding: "20px 14px",
        }}>
          <div style={{ fontSize: "10px", color: "#5865f2", letterSpacing: "2px", marginBottom: "10px" }}>FILTER</div>
          {Object.keys(FILTERS).map((f) => (
            <div key={f} onClick={() => setFilter(f)} style={{
              padding: "7px 10px",
              marginBottom: "3px",
              borderRadius: "5px",
              cursor: "pointer",
              background: filter === f ? "#5865f220" : "transparent",
              border: `1px solid ${filter === f ? "#5865f2" : "transparent"}`,
              fontSize: "11px",
              color: filter === f ? "#5865f2" : "#555",
              letterSpacing: "0.5px",
              transition: "all 0.12s",
            }}>
              {f.toUpperCase()}
            </div>
          ))}

          {pinned.length > 0 && (
            <div style={{ marginTop: "24px" }}>
              <div style={{ fontSize: "10px", color: "#ffaa00", letterSpacing: "2px", marginBottom: "10px" }}>
                ★ PINNED ({pinned.length})
              </div>
              {pinned.map((n) => (
                <div key={n} style={{
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "space-between",
                  padding: "5px 8px",
                  marginBottom: "3px",
                  borderRadius: "5px",
                  background: "#ffaa0012",
                  border: "1px solid #ffaa0025",
                }}>
                  <span style={{ fontSize: "13px", color: "#ffaa00", letterSpacing: "2px" }}>{n}</span>
                  <div style={{ display: "flex", gap: "4px" }}>
                    <span onClick={() => copyOne(n)} style={{ cursor: "pointer", fontSize: "10px", color: "#555" }} title="Copy">⎘</span>
                    <span onClick={() => pin(n)} style={{ cursor: "pointer", fontSize: "10px", color: "#555" }} title="Unpin">✕</span>
                  </div>
                </div>
              ))}
              <button onClick={() => {
                navigator.clipboard.writeText(pinned.join("\n"));
              }} style={{
                width: "100%",
                marginTop: "8px",
                padding: "6px",
                background: "#ffaa0015",
                border: "1px solid #ffaa0030",
                borderRadius: "5px",
                color: "#ffaa00",
                fontSize: "10px",
                cursor: "pointer",
                fontFamily: "monospace",
                letterSpacing: "1px",
              }}>
                COPY ALL PINNED
              </button>
            </div>
          )}
        </div>

        {/* Main grid */}
        <div style={{ flex: 1, padding: "20px 24px" }}>
          <div style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            marginBottom: "16px",
          }}>
            <div style={{ fontSize: "11px", color: "#444" }}>
              {filtered.length} NAMES SHOWN
            </div>
            <button onClick={copyAll} style={{
              background: copiedAll ? "#00ff8820" : "#1e2330",
              border: `1px solid ${copiedAll ? "#00ff88" : "#2a2f3d"}`,
              color: copiedAll ? "#00ff88" : "#888",
              padding: "7px 16px",
              borderRadius: "6px",
              fontFamily: "monospace",
              fontSize: "11px",
              cursor: "pointer",
              letterSpacing: "1px",
              transition: "all 0.15s",
            }}>
              {copiedAll ? "✓ COPIED!" : "⎘ COPY ALL"}
            </button>
          </div>

          <div style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fill, minmax(90px, 1fr))",
            gap: "8px",
          }}>
            {filtered.map((name) => {
              const isPinned = pinned.includes(name);
              const isCopied = copied === name;
              return (
                <div
                  key={name}
                  style={{
                    background: isCopied ? "#5865f220" : isPinned ? "#ffaa0012" : "#111318",
                    border: `1px solid ${isCopied ? "#5865f2" : isPinned ? "#ffaa0040" : "#1e2330"}`,
                    borderRadius: "8px",
                    padding: "10px 8px",
                    textAlign: "center",
                    cursor: "pointer",
                    transition: "all 0.15s",
                    position: "relative",
                  }}
                  onClick={() => copyOne(name)}
                >
                  <div style={{
                    fontSize: "16px",
                    letterSpacing: "3px",
                    fontWeight: "bold",
                    color: isCopied ? "#5865f2" : isPinned ? "#ffaa00" : "#e2e8f0",
                    marginBottom: "6px",
                  }}>
                    {isCopied ? "✓" : name}
                  </div>
                  <div style={{
                    display: "flex",
                    justifyContent: "center",
                    gap: "6px",
                  }}>
                    <span
                      onClick={(e) => { e.stopPropagation(); pin(name); }}
                      style={{
                        fontSize: "10px",
                        color: isPinned ? "#ffaa00" : "#333",
                        cursor: "pointer",
                        transition: "color 0.1s",
                      }}
                      title={isPinned ? "Unpin" : "Pin"}
                    >
                      ★
                    </span>
                    <span style={{ fontSize: "10px", color: "#333" }}>⎘</span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      <style>{`
        div:hover { }
        button:hover { opacity: 0.85; }
      `}</style>
    </div>
  );
}