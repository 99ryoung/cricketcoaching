# Cricket coaching app

A web app for managing players' Individual Development Plans (IDPs): player profiles, skill self-ratings and coach ratings on spider charts, bowling action safety checks, IDP goals and actions, training sessions, Play-Cricket dismissal analysis, and a player questionnaire players can fill in from a link.

- `index.html` is the coach dashboard. Coaches sign in with an emailed link.
- `q.html` is the player questionnaire. Players open a private link from their coach. They never sign in and can't see anything else.
- `privacy.html` is the privacy notice linked from the questionnaire. Fill in the bracketed parts with your Club Welfare Officer.

No build step: it's plain HTML and JavaScript, with data stored in Supabase.

## Setup

### 1. Supabase (database and coach sign-in)
1. Create a project at supabase.com. Choose the London region.
2. Open **SQL Editor → New query**, paste in `supabase/schema.sql` and click **Run**.
3. Go to **Authentication → Sign In / Providers**. Keep **Email** on and turn **Allow new users to sign up** off, so only coaches you add can sign in.
4. Go to **Authentication → Users → Add user → Send invitation** and add your own email (and any other coaches).
5. Go to **Authentication → URL Configuration**. Set **Site URL** to your Netlify address (step 2) and add it under **Redirect URLs**.
6. Go to **Project Settings → API** and copy the **Project URL** and the **publishable key** (or legacy anon key) into `js/config.js`. Never use the `service_role` key here.

### 2. Netlify (hosting)
1. Sign in to netlify.com with GitHub and choose **Add new site → Import an existing project → GitHub → cricketcoaching**.
2. Leave the build command empty and set the publish directory to `.`, then click **Deploy**.
3. Optional: under **Domain management**, rename the site or add a club subdomain such as `coaching.yourclub.co.uk`.

### 3. Using it
- Open the site, enter your email and click the link you're sent.
- Add a player, then use **Questionnaire link** to create their private link. Send it by WhatsApp or text (to a parent for juniors).
- When they've sent it, the player shows **New answers**. Open them and click **Add to this file**.
- **Hand to player** still works when you give the player your own phone.

## How the data is protected
- Each coach only sees the players they created (row-level security in `supabase/schema.sql`).
- Player links can only send answers in. They can't read data back, apart from the player's first name, squad and age group shown on the welcome screen.
- Each link accepts at most 5 submissions a day. **Replace link** turns off an old link.
- Pages are marked `noindex` so search engines don't list them.

## Notes for changes
`js/shared.js` copies the skill lists from `index.html` for the questionnaire. If you change skills in one, change the other.

## Player view (r.html)

On a player's page, click **Player view → Create player view** to get a private, read-only link (`r.html#r=CODE`).
It shows the spider chart, strengths and areas to work on, IDP goals and actions, planned training sessions and the next review date,
plus an optional message from the coach and the player's own cricket profile, which they can edit. Edits (and any injury update)
arrive as `responses` rows of kind `profile`; the dashboard applies them automatically. Medical details, coach notes,
bowling action notes and session reviews are never included.
The dashboard rebuilds that summary every time it saves the player; **Stop sharing** switches the link off.
Needs the `report_code` column and `get_report` function at the bottom of `supabase/schema.sql`.

## Player logins (player page at /player)

Players and parents sign in with email and password at `/player` (served by `r.html`).
On a player's file, **Player access** lists the emails allowed to see that player. Only those emails can create
an account (a database trigger blocks every other sign-up), and removing an email takes access away immediately.
Coaches are the users in the `coaches` table (whoever existed when the player-login SQL first ran).
Supabase settings: *Allow new users to sign up* must be **on** (the trigger does the gatekeeping), keep *Confirm email* on,
and set up custom SMTP before inviting many players, because the built-in email sender only sends a few emails an hour.
To add another coach later: in SQL, `drop trigger only_approved_signups on auth.users;`, invite them, insert their
`auth.users` id and email into `coaches`, then re-run the trigger section of `schema.sql`.
Old `r.html#r=CODE` share links keep working until the coach clicks **Turn off old link**.
