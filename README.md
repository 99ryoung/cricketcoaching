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
