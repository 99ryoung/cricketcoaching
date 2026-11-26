// Connects the coach dashboard to Supabase. Exposes window.coachBackend.
(function () {
  "use strict";
  const cfg = window.APP_CONFIG || {};
  const configured = cfg.supabaseUrl && !/YOUR-PROJECT/.test(cfg.supabaseUrl);
  const sb = configured ? window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseAnonKey) : null;
  let listeners = [], rows = [];
  const err = (e) => ({ code: "unavailable", message: (e && e.message) || String(e) });

  async function load() {
    const { data, error } = await sb.from("players").select("id,data");
    if (error) throw err(error);
    rows = data || [];
    emit();
  }
  function emit() {
    const snap = {
      metadata: { fromCache: false, hasPendingWrites: false },
      docs: rows.map((r) => ({ id: r.id, exists: true, data: () => r.data }))
    };
    listeners.forEach((l) => l.next(snap));
  }
  const db = {
    collection() {
      return {
        onSnapshot(next, onErr) {
          const l = { next, onErr };
          listeners.push(l);
          load().catch((e) => onErr && onErr(e));
          return () => { listeners = listeners.filter((x) => x !== l); };
        },
        doc(id) {
          return {
            async set(body) {
              const { error } = await sb.from("players").upsert({
                id, data: body, invite_code: body.inviteCode || null, updated_at: new Date().toISOString()
              });
              if (error) throw err(error);
              const i = rows.findIndex((r) => r.id === id);
              if (i >= 0) rows[i] = { id, data: body }; else rows.push({ id, data: body });
            },
            async delete() {
              const { error } = await sb.from("players").delete().eq("id", id);
              if (error) throw err(error);
              rows = rows.filter((r) => r.id !== id);
            }
          };
        }
      };
    }
  };
  // Pick up changes made on another device.
  window.addEventListener("focus", () => { if (listeners.length) load().catch(() => {}); });
  setInterval(() => { if (listeners.length && document.visibilityState === "visible") load().catch(() => {}); }, 120000);

  function showLogin(msg) {
    const el = document.getElementById("login");
    el.hidden = false;
    document.getElementById("loginMsg").textContent = msg || "";
  }
  async function ready() {
    if (!sb) { showLogin("This app isn't connected to its database yet. Add the Supabase details to js/config.js."); return null; }
    const { data } = await sb.auth.getSession();
    const session = data && data.session;
    if (!session) { showLogin(); return null; }
    const who = document.getElementById("whoami");
    if (who) who.textContent = session.user.email;
    return db;
  }
  document.addEventListener("submit", async (e) => {
    if (e.target.id !== "loginForm") return;
    e.preventDefault();
    const email = document.getElementById("loginEmail").value.trim();
    if (!email) return;
    const btn = e.target.querySelector("button");
    btn.disabled = true;
    const { error } = await sb.auth.signInWithOtp({
      email, options: { shouldCreateUser: false, emailRedirectTo: location.origin + location.pathname }
    });
    btn.disabled = false;
    document.getElementById("loginMsg").textContent = error
      ? "That didn't work: " + error.message + ". Only coaches added in Supabase can sign in."
      : "Check your email for a sign-in link. You can close this tab once you've used it.";
  });
  async function signOut() { if (sb) await sb.auth.signOut(); location.reload(); }
  async function fetchResponses() {
    if (!sb) return [];
    const { data, error } = await sb.from("responses").select("*").is("imported_at", null).order("submitted_at");
    if (error) return [];
    return data || [];
  }
  async function markImported(id) {
    const { error } = await sb.from("responses").update({ imported_at: new Date().toISOString() }).eq("id", id);
    if (error) throw err(error);
  }
  async function deleteResponse(id) {
    const { error } = await sb.from("responses").delete().eq("id", id);
    if (error) throw err(error);
  }
  window.coachBackend = { ready, signOut, fetchResponses, markImported, deleteResponse };
})();
