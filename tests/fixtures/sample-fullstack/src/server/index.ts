// Minimal Hono-style API so role detection sees a backend.
export const routes = { "GET /health": () => ({ ok: true }) };
