// Run from the repository root with: node --test "worker/test/*.test.ts"
// Node 24 runs this TypeScript directly. The Worker globals it needs (caches.default,
// crypto.subtle.timingSafeEqual) are stood in for below; fetch is replaced per test.
import assert from "node:assert/strict";
import { createHash, timingSafeEqual } from "node:crypto";
import { beforeEach, describe, it } from "node:test";

import worker from "../src/index.ts";

const store = new Map<string, Response>();
const fakeCache = {
  async match(key: Request): Promise<Response | undefined> {
    return store.get(key.url)?.clone();
  },
  async put(key: Request, response: Response): Promise<void> {
    store.set(key.url, response.clone());
  },
};
Object.assign(globalThis, { caches: { default: fakeCache } });
Object.assign(crypto.subtle, {
  timingSafeEqual: (a: ArrayBuffer, b: ArrayBuffer) => timingSafeEqual(Buffer.from(a), Buffer.from(b)),
});

const GOOD = `-- Rayfield Gen2 v1.2.0\n${"local x = 1\n".repeat(200)}`;
const OTHER = `-- Rayfield Gen2 v9.9.9\n${"local y = 2\n".repeat(200)}`;
const sha = (s: string) => createHash("sha256").update(s).digest("hex");

let fetched: string[] = [];
function upstream(answer: (url: string) => Response) {
  fetched = [];
  globalThis.fetch = (async (input: RequestInfo | URL) => {
    const url = String(input);
    fetched.push(url);
    return answer(url);
  }) as typeof fetch;
}

async function get(url: string, env: Record<string, string> = {}, headers: Record<string, string> = {}) {
  const waits: Promise<unknown>[] = [];
  const ctx = { waitUntil: (p: Promise<unknown>) => waits.push(p), passThroughOnException() {} };
  const res = await worker.fetch(new Request(url, { headers }), env, ctx as unknown as ExecutionContext);
  await Promise.all(waits);
  return res;
}

const PINNED = { GEN2_TAG: "1.2.0", GEN2_SHA256_ALLOWLIST: sha(GOOD) };

function assertSecured(res: Response) {
  assert.equal(res.headers.get("x-content-type-options"), "nosniff");
  assert.match(res.headers.get("content-security-policy") ?? "", /default-src 'none'.*frame-ancestors 'none'/);
  assert.match(res.headers.get("strict-transport-security") ?? "", /max-age=/);
}

beforeEach(() => store.clear());

describe("stable channel", () => {
  it("serves the pinned tag when its digest is allowed", async () => {
    upstream(() => new Response(GOOD));
    const res = await get("https://sirius.menu/gen2", PINNED);
    assert.equal(res.status, 200);
    assert.equal(await res.text(), GOOD);
    assert.deepEqual(fetched, ["https://github.com/SiriusSoftwareLtd/rayfield-gen2/releases/download/1.2.0/bundled.luau"]);
    assert.equal(res.headers.get("x-rayfield-integrity"), "sha256-allowlist");
    assert.equal(res.headers.get("x-rayfield-sha256"), sha(GOOD));
    assertSecured(res);
  });

  it("refuses a body whose digest is not allowed", async () => {
    upstream(() => new Response(OTHER));
    const res = await get("https://sirius.menu/gen2", PINNED);
    assert.equal(res.status, 502);
    assert.doesNotMatch(await res.text(), /v9\.9\.9/);
    assert.equal(res.headers.get("x-rayfield-upstream"), "digest");
  });

  it("falls back to the last verified copy when the digest stops matching", async () => {
    upstream(() => new Response(GOOD));
    await get("https://sirius.menu/gen2", PINNED);
    const realNow = Date.now;
    Date.now = () => realNow() + 10 * 60 * 1000;
    try {
      upstream(() => new Response(OTHER));
      const res = await get("https://sirius.menu/gen2", PINNED);
      assert.equal(res.status, 200);
      assert.equal(await res.text(), GOOD);
      assert.equal(res.headers.get("x-rayfield-cache"), "stale");
      assert.equal(fetched.length, 1);
    } finally {
      Date.now = realNow;
    }
  });

  it("falls back to the last verified copy when GitHub fails", async () => {
    upstream(() => new Response(GOOD));
    await get("https://sirius.menu/gen2", PINNED);
    upstream(() => new Response("rate limited", { status: 429 }));
    const res = await get("https://sirius.menu/gen2?__fresh=1", { ...PINNED, CACHE_BYPASS_SECRET: "s" }, { "x-cache-bypass": "s" });
    assert.equal(res.status, 200);
    assert.equal(await res.text(), GOOD);
    assert.equal(res.headers.get("x-rayfield-cache"), "stale");
  });

  it("fails closed on an allowlist with no valid digest", async () => {
    upstream(() => new Response(GOOD));
    const res = await get("https://sirius.menu/gen2", { GEN2_TAG: "1.2.0", GEN2_SHA256_ALLOWLIST: "not-a-digest" });
    assert.equal(res.status, 502);
    assert.equal(fetched.length, 0);
  });

  it("fails closed on a malformed tag", async () => {
    upstream(() => new Response(GOOD));
    const res = await get("https://sirius.menu/gen2", { GEN2_TAG: "../latest", GEN2_SHA256_ALLOWLIST: sha(GOOD) });
    assert.equal(res.status, 502);
    assert.equal(fetched.length, 0);
  });

  it("ignores a cached copy that is not on the current allowlist", async () => {
    upstream(() => new Response(GOOD));
    await get("https://sirius.menu/gen2", PINNED);
    upstream(() => new Response("gone", { status: 404 }));
    const res = await get("https://sirius.menu/gen2", { GEN2_TAG: "1.2.0", GEN2_SHA256_ALLOWLIST: sha(OTHER) });
    assert.equal(res.status, 502);
  });

  it("keeps serving releases/latest when nothing is configured", async () => {
    upstream(() => new Response(GOOD));
    const res = await get("https://sirius.menu/gen2");
    assert.equal(res.status, 200);
    assert.deepEqual(fetched, ["https://github.com/SiriusSoftwareLtd/rayfield-gen2/releases/latest/download/bundled.luau"]);
    assert.equal(res.headers.get("x-rayfield-integrity"), "unverified");
  });

  it("rejects an HTML error page and a short body", async () => {
    upstream(() => new Response(`<!doctype html>${"x".repeat(5000)}`));
    assert.equal((await get("https://sirius.menu/gen2")).status, 502);
    upstream(() => new Response("-- tiny"));
    const res = await get("https://sirius.menu/gen2");
    assert.equal(res.status, 502);
    assert.equal(res.headers.get("x-rayfield-upstream"), "shape");
  });

  it("shares one cache entry between www and the apex", async () => {
    upstream(() => new Response(GOOD));
    await get("https://sirius.menu/gen2", PINNED);
    upstream(() => new Response("down", { status: 500 }));
    const res = await get("https://www.sirius.menu/gen2", PINNED);
    assert.equal(res.status, 200);
    assert.equal(await res.text(), GOOD);
    assert.equal(fetched.length, 0);
  });
});

describe("cache bypass", () => {
  it("ignores ?__fresh=1 without the right header", async () => {
    upstream(() => new Response(GOOD));
    await get("https://sirius.menu/gen2", PINNED);
    upstream(() => new Response(GOOD));
    const env = { ...PINNED, CACHE_BYPASS_SECRET: "right" };
    await get("https://sirius.menu/gen2?__fresh=1", env, { "x-cache-bypass": "wrong" });
    await get("https://sirius.menu/gen2?__fresh=1", env);
    assert.equal(fetched.length, 0);
    await get("https://sirius.menu/gen2?__fresh=1", env, { "x-cache-bypass": "right" });
    assert.equal(fetched.length, 1);
  });

  it("is off when the secret is unset", async () => {
    upstream(() => new Response(GOOD));
    await get("https://sirius.menu/gen2", PINNED);
    upstream(() => new Response(GOOD));
    await get("https://sirius.menu/gen2?__fresh=1", PINNED, { "x-cache-bypass": "" });
    assert.equal(fetched.length, 0);
  });
});

describe("preview channel", () => {
  it("serves the rolling preview and says it is unverified", async () => {
    upstream(() => new Response(OTHER));
    const res = await get("https://sirius.menu/gen2-preview", PINNED);
    assert.equal(res.status, 200);
    assert.deepEqual(fetched, ["https://github.com/SiriusSoftwareLtd/rayfield-gen2/releases/download/preview/bundled.luau"]);
    assert.equal(res.headers.get("x-rayfield-integrity"), "unverified");
    assertSecured(res);
  });

  it("still rejects an HTML body", async () => {
    upstream(() => new Response(`<html>${"x".repeat(5000)}`));
    const res = await get("https://sirius.menu/gen2-preview");
    assert.equal(res.status, 502);
    assert.match(await res.text(), /No Rayfield Gen2 preview build/);
  });
});

describe("other requests", () => {
  it("404s unknown paths and 405s other methods, with security headers", async () => {
    upstream(() => new Response(GOOD));
    const missing = await get("https://sirius.menu/gen2x");
    assert.equal(missing.status, 404);
    assertSecured(missing);
    const post = await worker.fetch(
      new Request("https://sirius.menu/gen2", { method: "POST" }),
      {},
      { waitUntil() {}, passThroughOnException() {} } as unknown as ExecutionContext,
    );
    assert.equal(post.status, 405);
    assertSecured(post);
    assert.equal(fetched.length, 0);
  });
});
