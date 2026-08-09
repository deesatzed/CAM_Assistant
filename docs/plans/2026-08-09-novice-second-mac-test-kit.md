# Novice Second-Mac Test Kit Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a clone-ready, plain-language human testing kit for the product owner to run on a second Mac with CAM Assistant and Local AI installed.

**Architecture:** Four linked Markdown documents under `docs/pilots/` separate preparation, execution, observation capture, and run-level results. The checklist uses fixed synthetic facts and stable test IDs so every unexpected outcome can be tied to a reproducible report without collecting sensitive data.

**Tech Stack:** Markdown, Git, existing CAM Assistant packaged-app workflow, existing Ollama/LM Studio local OpenAI-compatible integration.

---

### Task 1: Create the preparation guide

**Files:**
- Create: `docs/pilots/NOVICE_TEST_START_HERE.md`
- Reference: `README.md`
- Reference: `docs/pilots/barebones-general-user-protocol.md`
- Reference: `docs/pilots/direction-general-user-protocol.md`

**Step 1: Define the clean-run boundary**

State that the tester is the product owner on another Mac, should use only the
prepared fictional content, and should record the Git commit tested.

**Step 2: Provide clone, build, package, and launch steps**

Use the repository's current standalone commands and clearly identify unsigned
first-launch friction as distribution behavior.

**Step 3: Define synthetic test material**

Provide exact clipboard text, watched-folder text, fictional Direction entries,
supported questions, and an unsupported question with known expected results.

**Step 4: Define evidence names and stop rules**

Use a run ID plus test ID for screenshots/recordings. Stop on privacy, data-loss,
source mutation, unsupported-fact, or unsafe-restore behavior.

**Step 5: Validate the guide**

Run:

```bash
rg -n "Run ID|synthetic|git clone|package-app|Stop immediately|NOVICE_TEST_CHECKLIST" docs/pilots/NOVICE_TEST_START_HERE.md
```

Expected: every required preparation and safety section is found.

### Task 2: Create the complete check-off journey

**Files:**
- Create: `docs/pilots/NOVICE_TEST_CHECKLIST.md`
- Reference: `GOAL_BAREBONES.md`
- Reference: `GOAL_DIRECTION.md`
- Reference: `docs/pilots/NOVICE_TEST_START_HERE.md`

**Step 1: Add run metadata and result key**

Include checkboxes for Pass, Problem, Confusing, Enhancement, and Skipped, plus
a place for evidence filenames and problem-report IDs.

**Step 2: Add numbered tests in product order**

Cover first launch, three-place navigation, clipboard save/deduplication,
Library/search/source details, model-free Ask, unsupported Ask, Keep/duplicate/
Undo, Direction, live Local AI Ask/Talk, watched folder, restart persistence,
backup/validation/fresh restore, keyboard/readability/privacy, and final review.

**Step 3: Give every test an expectation**

Each stable test ID must say why the feature matters, what to do, what should
happen, what evidence to collect, and whether an unexpected result is safe to
continue past.

**Step 4: Preserve proof boundaries**

Do not call waived human gates passed. Distinguish offline results from live
model results and local test-build results from signed/notarized release proof.

**Step 5: Validate coverage**

Run:

```bash
rg -n "TEST-(LAUNCH|NAV|SAVE|LIB|ASK|KEEP|DIR|AI|WATCH|RESTART|BACKUP|ACCESS|FINAL)-" docs/pilots/NOVICE_TEST_CHECKLIST.md
```

Expected: every planned journey family has at least one stable test ID.

### Task 3: Create observation and results templates

**Files:**
- Create: `docs/pilots/NOVICE_TEST_PROBLEM_REPORT.md`
- Create: `docs/pilots/NOVICE_TEST_RESULTS.md`

**Step 1: Create the reusable problem form**

Capture classification, severity, test ID, expectation, actual outcome,
reproduction actions, repeatability, exact error text, evidence filenames,
restart result, privacy review, and requested improvement.

**Step 2: Create the run summary**

Capture Mac/app/model identity, completed/passed/problem/confusing/enhancement/
skipped counts, stop-rule events, problem-report index, section verdicts, and
the three approved final questions.

**Step 3: Add honest verdict choices**

Use `PASS`, `PASS WITH IMPROVEMENTS`, `INCOMPLETE`, and `STOPPED FOR SAFETY`.
State that this record does not automatically change goals or release status.

**Step 4: Validate required fields**

Run:

```bash
rg -n "Expected|Actually|Repeat|Severity|Privacy|Evidence" docs/pilots/NOVICE_TEST_PROBLEM_REPORT.md
rg -n "PASS WITH IMPROVEMENTS|INCOMPLETE|STOPPED FOR SAFETY|trust|without instructions|single change" docs/pilots/NOVICE_TEST_RESULTS.md
```

Expected: all observation and verdict fields are present.

### Task 4: Link, review, and publish the kit

**Files:**
- Modify: `README.md`
- Modify: `PROGRESS.md`
- Review: `docs/pilots/NOVICE_TEST_START_HERE.md`
- Review: `docs/pilots/NOVICE_TEST_CHECKLIST.md`
- Review: `docs/pilots/NOVICE_TEST_PROBLEM_REPORT.md`
- Review: `docs/pilots/NOVICE_TEST_RESULTS.md`

**Step 1: Link the kit from the README**

Add a short “Test on another Mac” route pointing first to
`NOVICE_TEST_START_HERE.md` without changing product-completion claims.

**Step 2: Record progress honestly**

Add a current entry stating that the kit is ready to run but no new human
result has been produced.

**Step 3: Check all local Markdown links**

Run a bounded link-target check for relative Markdown links in the four files.
Expected: every repository-local target exists.

**Step 4: Check formatting and repository state**

Run:

```bash
git diff --check
git status --short --branch
```

Expected: no whitespace errors; only intended documentation files are changed.

**Step 5: Commit and push**

```bash
git add README.md PROGRESS.md docs/pilots/NOVICE_TEST_*.md docs/plans/2026-08-09-novice-second-mac-test-kit.md
git commit -m "docs: add novice second-Mac testing kit"
git push origin main
```

Expected: `origin/main` contains the complete clone-ready kit.
