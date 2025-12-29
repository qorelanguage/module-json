# Copilot Code Review Instructions

## Project Context
This is the Qore JSON module providing JSON serialization/deserialization, JSON-RPC support, and MCP (Model Context Protocol) client/server implementations.

## Code Review Focus Areas

### Memory Safety
- Check for proper memory management in C++ code (src/*.qpp)
- Verify no memory leaks in string/buffer operations
- Ensure proper error handling that doesn't leak resources

### Protocol Compliance
- JSON-RPC 1.0, 1.1, and 2.0 specification compliance
- MCP protocol version compliance (2024-11-05, 2025-03-26, 2025-06-18, 2025-11-25)
- RFC 6901 (JSON Pointer) compliance

### Error Handling
- Verify exceptions are properly propagated
- Check that error messages are informative
- Ensure no silent failures

### Test Coverage
- New functionality should have corresponding tests
- Edge cases and negative tests are important
- Protocol version compatibility tests

## Language Notes
- Qore is a dynamically-typed language similar to Python/Perl
- `.qpp` files are Qore preprocessor files that generate C++ bindings
- `.qm` files are Qore modules
- `.qc` files are Qore class files
