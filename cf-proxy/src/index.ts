const JIOSAAVN = "https://www.jiosaavn.com";

const ALLOWED_ORIGINS = [
  "https://dew-one.vercel.app",
  "http://localhost:3000",
  "http://localhost:3001",
];

const HEADERS_TO_JIOSAAVN: Record<string, string> = {
  "User-Agent":
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
  Accept: "application/json, text/javascript, */*; q=0.01",
  "Accept-Language": "en-US,en;q=0.9",
  Referer: "https://www.jiosaavn.com/",
  Origin: "https://www.jiosaavn.com",
  Cookie: "L=english; DL=english; gdpr_acceptance=true",
  "X-Requested-With": "XMLHttpRequest",
};

function corsHeaders(origin: string | null): Record<string, string> {
  const allowed =
    origin && ALLOWED_ORIGINS.some((o) => origin.startsWith(o))
      ? origin
      : ALLOWED_ORIGINS[0];
  return {
    "Access-Control-Allow-Origin": allowed,
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Max-Age": "86400",
  };
}

export default {
  async fetch(request: Request): Promise<Response> {
    const origin = request.headers.get("Origin");
    const cors = corsHeaders(origin);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: cors });
    }

    if (request.method !== "GET") {
      return new Response("Method not allowed", { status: 405, headers: cors });
    }

    const url = new URL(request.url);
    const path = url.pathname + url.search;

    if (!url.search) {
      return new Response(
        JSON.stringify({ error: "Missing query parameters" }),
        { status: 400, headers: { ...cors, "Content-Type": "application/json" } }
      );
    }

    const apiUrl = `${JIOSAAVN}${path}`;

    try {
      const res = await fetch(apiUrl, {
        headers: HEADERS_TO_JIOSAAVN,
      });

      const body = await res.text();

      return new Response(body, {
        status: res.status,
        headers: {
          ...cors,
          "Content-Type": res.headers.get("Content-Type") || "application/json",
          "Cache-Control": "public, s-maxage=300, stale-while-revalidate=600",
        },
      });
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return new Response(
        JSON.stringify({ error: `Proxy error: ${msg}` }),
        { status: 502, headers: { ...cors, "Content-Type": "application/json" } }
      );
    }
  },
} satisfies ExportedHandler;
