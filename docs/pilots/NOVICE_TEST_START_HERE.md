# CAM Assistant Test on Another Mac — Start Here

This guide is for one person testing CAM Assistant on a different Mac. You do
not need to know how the app is built. Follow the checklist, compare what you
see with the expected result, and record anything that feels broken or unclear.

## What you will need

- A Mac running macOS 15 or later.
- Ollama or LM Studio with a local model already installed.
- About 60–90 minutes. You may stop between checklist sections.
- No real private information. This test uses fictional material supplied below.

## What your job is

You are testing what it feels like to use the app. You are **not** expected to
find the technical cause of a problem.

For each test, choose one or more results:

- **Pass:** it behaved exactly as expected.
- **Problem:** something failed, froze, disappeared, or produced a wrong result.
- **Confusing:** it worked, but you were unsure what to do or what it meant.
- **Enhancement:** it worked, but you can describe a better experience.
- **Skipped:** you could not or chose not to run the test.

## Privacy rules

Use only the synthetic content in this guide. Do not test with:

- passwords, API keys, recovery codes, or account information;
- medical, financial, legal, or employment records;
- private messages or files belonging to someone else; or
- anything you would not want included in a screenshot.

Before sharing a screenshot or recording, look at the entire image for names,
notifications, browser tabs, menu-bar details, and other private information.

## Stop immediately if

Stop the test, leave the app in its current state, and record a problem if CAM
Assistant appears to:

- send content to an unexpected cloud service or website;
- overwrite or delete existing app data;
- change or delete the original watched-folder file;
- present an answer as supported when no matching source exists;
- restore a backup over the currently used app data; or
- display a password, credential, or unrelated private content.

For ordinary wording problems, confusing navigation, or one feature failing
without risk to data, record the observation and continue when you feel safe.

## Step 1: Get the current app

Open **Terminal** and run these commands one line at a time:

```bash
git clone https://github.com/deesatzed/CAM_Assistant.git
cd CAM_Assistant
git status --short --branch
/bin/zsh scripts/package-app.sh
```

Expected:

- Git reports branch `main`.
- Packaging finishes without an error.
- The app appears at `artifacts/CAM Assistant.app` inside the cloned folder.

Record the exact version you are testing:

```bash
git rev-parse HEAD
```

Copy the displayed letters and numbers into the **Build commit** field in the
checklist and results page.

If packaging fails, stop before product testing. Create a problem report with
the exact Terminal message and a screenshot.

## Step 2: Create a run folder

Choose a Run ID using this format:

```text
YYYY-MM-DD-second-mac
```

Example: `2026-08-10-second-mac`

On the Desktop, create a folder named:

```text
CAM Test YYYY-MM-DD
```

Inside it, create these folders:

```text
Evidence
Problem Reports
Watched Folder
Restore Destination
```

Keep screenshots and recordings in `Evidence`. Copy
`NOVICE_TEST_PROBLEM_REPORT.md` into `Problem Reports` each time you need a new
report. At the end, place your completed checklist and results page in the main
run folder.

## Step 3: Prepare the exact synthetic content

### Clipboard note

Copy this exact paragraph when the checklist asks for it:

```text
The Wednesday planning call starts at 10:00 AM in the east office. Bring the blue folder.
```

Known facts:

- Event: Wednesday planning call
- Time: 10:00 AM
- Place: east office
- Item: blue folder

### Watched-folder file

Using TextEdit:

1. Choose **Format → Make Plain Text**.
2. Enter this exact sentence:

   ```text
   The blue garden key is stored in the kitchen drawer.
   ```

3. Save it inside `Watched Folder` as `garden-key.txt`.

Known fact: the blue garden key is in the kitchen drawer.

### Direction profile

Use these fictional entries:

- Person: `Jordan Lee`
- Relationship: `Friend`
- Promise: `Send Jordan the garden photos by Friday`
- Toward: `Jordan Lee`
- North star: `Make time for people and promises that matter`

### Supported questions

Use the exact wording supplied in the checklist. Small wording differences can
change search results, so do not improvise during the first run.

### Unsupported question

```text
What time does the purple lighthouse close?
```

There is no purple lighthouse information in the test material. The app should
say it does not have enough information or show no matching evidence. It must
not invent a closing time.

## Step 4: Prepare Local AI

The checklist tests both offline behavior and optional Local AI behavior.

Start with the local server stopped:

- **LM Studio:** stop the local server in LM Studio.
- **Ollama:** quit Ollama from its menu-bar icon if that option is available.

Later, the checklist will ask you to start the server and load the installed
model. Do not change model endpoints or open Advanced settings unless the
ordinary Local AI screen cannot find the running model.

## Step 5: Open the test documents

Keep these files available while testing:

1. [`NOVICE_TEST_CHECKLIST.md`](NOVICE_TEST_CHECKLIST.md) — follow and check off.
2. [`NOVICE_TEST_PROBLEM_REPORT.md`](NOVICE_TEST_PROBLEM_REPORT.md) — copy once
   per problem, confusing moment, or enhancement.
3. [`NOVICE_TEST_RESULTS.md`](NOVICE_TEST_RESULTS.md) — complete after testing.

You may edit Markdown in TextEdit as plain text, Xcode, Visual Studio Code, or
any editor you already know. Replace `[ ]` with `[x]` to check a box.

## Evidence naming

Name evidence using the Run ID and checklist Test ID:

```text
RUN-ID_TEST-ID_short-description.png
RUN-ID_TEST-ID_short-description.mov
```

Example:

```text
2026-08-10-second-mac_TEST-ASK-03_unsupported-answer.png
```

Name problem reports in order:

```text
P01_TEST-ID_short-description.md
P02_TEST-ID_short-description.md
```

The checklist has a space to record every evidence filename and problem-report
ID.

## Screenshot and recording shortcuts

- Screenshot an area: **Shift–Command–4**
- Screenshot a window: **Shift–Command–4**, then press **Space**
- Screenshot/recording controls: **Shift–Command–5**

Capture the full app window when layout matters. Capture a smaller area when an
error message is the only relevant detail.

## Ready check

Before opening the app, confirm:

- [ ] I recorded my Run ID.
- [ ] I recorded the tested Git commit.
- [ ] The packaged app exists.
- [ ] I created the run and evidence folders.
- [ ] I prepared only the supplied synthetic content.
- [ ] Local AI is stopped for the first part of the test.
- [ ] I know the safety stop rules.
- [ ] I opened the checklist and report templates.

Continue with [`NOVICE_TEST_CHECKLIST.md`](NOVICE_TEST_CHECKLIST.md).
