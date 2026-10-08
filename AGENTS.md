# Contributor guidance

Keep the core package pure MoonBit and portable across wasm, wasm-gc, JS and native.
Reuse MoonLoom for CID, unsigned varints and hash verification. This package owns
CAR framing and archive policies, not a replacement CID or general CBOR library.
Separate top-level items with `///|`. New public behavior needs black-box tests.
Use `.mbtx` for agent-authored automation. Run check, tests, format and info.
Do not claim public publication, interoperability or competition acceptance
without recorded evidence. Competition proposal text must be written by a human.
