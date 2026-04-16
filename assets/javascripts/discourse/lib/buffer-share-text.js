const EXCERPT_LIMIT = 100;

function stripToPlainText(html) {
  if (!html) {
    return "";
  }

  const doc = new DOMParser().parseFromString(html, "text/html");
  return (doc.body.textContent || "").replace(/\s+/g, " ").trim();
}

function truncate(text, limit) {
  if (text.length <= limit) {
    return text;
  }

  return text
    .slice(0, limit)
    .replace(/\s+\S*$/, "")
    .trimEnd();
}

export function buildBufferShareText({ title, excerpt, url }) {
  const parts = [title];

  const cleanExcerpt = stripToPlainText(excerpt).replace(/…+$/u, "").trim();

  if (cleanExcerpt.length > 0) {
    parts.push(`${truncate(cleanExcerpt, EXCERPT_LIMIT)}…`);
  }

  parts.push(url);

  return parts.join("\n\n");
}
