# QualCoder Enhancement Gameplan

## Executive Summary

This document outlines a strategic plan for enhancing the QualCoder tool based on three user-requested features:
1. **Transcript cleanup/parsing** - Detect and format speaker turns (Task/Question/Participant/Moderator)
2. **One-pager export per theme** - Export formatted reports for individual tags
3. **Tag descriptions** - Add descriptions to tags for richer reporting

---

## A. Feature Specifications

### A1. Transcript Cleanup on Import

#### Exact Behavior

**Detection Phase (on import):**
1. When user pastes transcript text, analyze each line/paragraph for speaker patterns
2. Detect common Userlytics patterns:
   - `Task:` or `Task 1:` - Study task instructions
   - `Question:` or `Q:` - Moderator questions
   - `Participant:` or `P:` or `User:` - Participant responses
   - `Moderator:` or `M:` or `Interviewer:` - Moderator prompts
   - Timestamps like `[00:15]` or `(0:15)` - Strip or preserve as metadata
3. Assign each text block a `speakerType` enum: `task`, `question`, `participant`, `moderator`, `unknown`

**Visual Distinction (in coding view):**
```
+--------------------------------------------------+
| TASK 1                                    [task] |
| "Navigate to the checkout page and complete      |
|  a purchase using your saved payment method."    |
+--------------------------------------------------+
| Q: How easy was it to find the checkout button?  |
+--------------------------------------------------+
| P1: "It was actually pretty confusing because    | <-- taggable
|      the button was below the fold and I..."     |
+--------------------------------------------------+
| P1: "...had to scroll down to find it."          | <-- taggable
+--------------------------------------------------+
```

**UI Design:**
- Task/Question blocks: Gray background, muted text, NOT taggable (or optionally taggable with a toggle)
- Participant responses: White/normal background, fully taggable
- Left border color coding:
  - Task: orange/amber `#f59e0b`
  - Question: blue `#3b82f6`
  - Participant: green `#10b981`
  - Moderator: purple `#8b5cf6`
- Speaker label pill shown in top-right of each block

**Import Modal Changes:**
- Add checkbox: "Auto-detect speaker turns" (default: ON)
- Add preview button: "Preview Parsing" to see how transcript will be split
- Add dropdown for "Transcript format": Userlytics | Generic | Raw (no parsing)

#### Data Model Changes

**Excerpt entity additions:**
```javascript
excerpt: {
    id: string,
    transcriptId: string,
    text: string,
    index: number,
    tagIds: string[],
    createdAt: string,
    // NEW FIELDS:
    speakerType: 'task' | 'question' | 'participant' | 'moderator' | 'unknown',
    speakerLabel: string,        // e.g., "P1", "Moderator", "Task 2"
    taskContext: string | null,  // The most recent task text (for context in exports)
    questionContext: string | null,  // The most recent question (for context in exports)
    rawLineNumber: number | null,    // Original line number in source
    timestamp: string | null     // If timestamp was detected, e.g., "01:45"
}
```

**Transcript entity additions:**
```javascript
transcript: {
    // existing fields...
    // NEW FIELDS:
    parseFormat: 'userlytics' | 'generic' | 'raw',
    participantCount: number,    // Number of unique participant speakers detected
    taskCount: number            // Number of tasks detected
}
```

#### Edge Cases

| Edge Case | Handling |
|-----------|----------|
| No speaker labels detected | Fall back to sentence-by-sentence split, all marked `unknown` |
| Mixed formats in one transcript | Best-effort detection; allow manual override |
| Multi-paragraph speaker turns | Group consecutive paragraphs under same speaker until new speaker detected |
| Timestamps embedded in text | Extract and store separately, strip from display text |
| Speaker labels mid-sentence | Split at speaker label, create new excerpt |
| Empty lines between speakers | Use as natural boundaries, don't create empty excerpts |
| Partial speaker labels (e.g., "P:" vs "Participant 1:") | Normalize to consistent format in `speakerLabel` |

---

### A2. One-Pager Export Per Theme

#### Exact Behavior

**Trigger:**
- In Database view, when a tag is selected in filter, show "Export One-Pager" button
- Alternatively, in a new "Tags" management view, each tag has an "Export" action

**Export Dialog:**
```
+----------------------------------------+
| Export One-Pager: "checkout-friction"  |
+----------------------------------------+
| Format:  [HTML for Print v]            |
|                                        |
| Include:                               |
| [x] Tag description                    |
| [x] Participant reference numbers      |
| [x] Question/task context              |
| [x] Excerpt count summary              |
| [ ] Full transcript source links       |
|                                        |
| [Cancel]           [Export One-Pager]  |
+----------------------------------------+
```

**Output Document Structure:**
```
====================================
THEME: Checkout Friction
====================================

DESCRIPTION:
Users expressing confusion, frustration, or
difficulty during the checkout flow, including
payment entry, address forms, and order confirmation.

SUMMARY:
- 12 excerpts from 5 participants
- Related themes: "payment-anxiety", "form-fatigue"

------------------------------------
EXCERPTS
------------------------------------

[P1] "It was actually pretty confusing because
     the button was below the fold."

     Context: Task 1 - Navigate to checkout
     Source: User 5 - Checkout Flow (Sentence #14)

[P2] "I kept looking for a 'Buy Now' button but
     it just said 'Continue' which was weird."

     Context: Q: How did you proceed to payment?
     Source: User 8 - Checkout Flow (Sentence #23)

[P1] "The form asked for my phone number twice
     and I wasn't sure which one to fill."

     Context: Task 2 - Enter shipping details
     Source: User 5 - Checkout Flow (Sentence #31)

------------------------------------
Generated by QualCoder | 2024-01-15
====================================
```

#### Data Model Changes

None required for export itself, but depends on A1 (speaker context) and A3 (tag descriptions).

#### Edge Cases

| Edge Case | Handling |
|-----------|----------|
| Tag has no description | Show placeholder: "No description provided. Add one in Tag Management." |
| Excerpt has no question/task context | Omit context line, just show source |
| Very long excerpts | Show full text (don't truncate) but add line breaks for readability |
| Special characters in text | Escape properly for HTML output |
| Tag name with special chars | Sanitize for filename |

---

### A3. Tag Descriptions

#### Exact Behavior

**Creating/Editing Tags:**
- When creating a tag (via popover), after typing name and pressing Enter:
  - Tag is created immediately (current behavior)
  - Small "Add description" link appears below the new tag
  - Clicking opens inline text area
- In Tags management view (NEW):
  - List all tags with name, usage count, description preview
  - Click to expand/edit description
  - Delete unused tags

**Tag Popover Enhancement:**
```
+-------------------------------+
| Search or create tag...       |
+-------------------------------+
| EXISTING TAGS                 |
| [x] checkout-friction    (12) |
|     "Users expressing..."     |  <-- description preview (truncated)
| [ ] payment-anxiety       (8) |
| [ ] form-fatigue          (5) |
+-------------------------------+
| + Create "new-tag-name"       |
+-------------------------------+
```

**Tags Management View (New Tab):**
```
+--------------------------------------------------+
| Tags                              [+ New Tag]    |
+--------------------------------------------------+
| checkout-friction                         12 uses|
| Users expressing confusion, frustration,         |
| or difficulty during the checkout flow...        |
| [Edit Description] [Rename] [Delete]             |
+--------------------------------------------------+
| payment-anxiety                            8 uses|
| No description yet                               |
| [Add Description] [Rename] [Delete]              |
+--------------------------------------------------+
```

#### Data Model Changes

**Tag entity additions:**
```javascript
tag: {
    id: string,
    name: string,
    usageCount: number,
    createdAt: string,
    // NEW FIELDS:
    description: string,    // 2-4 sentences about the theme
    color: string | null,   // Optional: custom color for visual grouping
    parentTagId: string | null,  // Optional: for hierarchical tags (future)
    updatedAt: string
}
```

#### Edge Cases

| Edge Case | Handling |
|-----------|----------|
| Very long descriptions | Truncate in UI with "..." and "Show more" |
| Empty description | Show "(No description)" in muted text |
| Description with special chars | Store raw, escape on display |
| Deleting tag with excerpts | Show warning, offer to reassign or remove tag from all excerpts |
| Merging duplicate tags | Future feature - for now, just warn if similar name exists |

---

## B. Transcript Parsing Strategy

### B1. Detection Patterns

**Primary Patterns (Userlytics format):**
```javascript
const SPEAKER_PATTERNS = {
    task: [
        /^Task\s*\d*[:\s]/i,           // "Task:", "Task 1:", "Task 2 "
        /^\[Task\s*\d*\]/i,            // "[Task]", "[Task 1]"
        /^TASK\s*\d*[:\s]/              // "TASK:", "TASK 1:"
    ],
    question: [
        /^(Question|Q)\s*\d*[:\s]/i,   // "Question:", "Q:", "Q1:"
        /^\[Q\d*\]/i,                   // "[Q]", "[Q1]"
        /^Interviewer[:\s]/i            // "Interviewer:"
    ],
    moderator: [
        /^(Moderator|M)[:\s]/i,        // "Moderator:", "M:"
        /^Facilitator[:\s]/i,
        /^Researcher[:\s]/i
    ],
    participant: [
        /^(Participant|P|User|U)\s*\d*[:\s]/i,  // "Participant:", "P1:", "User 3:"
        /^(Respondent|R)\s*\d*[:\s]/i,
        /^Tester\s*\d*[:\s]/i
    ],
    timestamp: [
        /^\[?\d{1,2}:\d{2}(:\d{2})?\]?\s*/,  // [01:23], (1:23:45), 01:23
        /^\(\d{1,2}:\d{2}(:\d{2})?\)\s*/
    ]
};
```

**Secondary Patterns (common in automated transcripts):**
```javascript
const AUTOMATED_PATTERNS = {
    speaker_name: /^[A-Z][a-z]+\s[A-Z][a-z]*[:\s]/,  // "John Smith:"
    speaker_initial: /^[A-Z]{1,3}[:\s]/,              // "JS:", "JD:"
};
```

### B2. Visual Distinction Implementation

**CSS for speaker types:**
```css
.sentence-item[data-speaker="task"] {
    background: rgba(245, 158, 11, 0.1);
    border-left: 4px solid #f59e0b;
    opacity: 0.8;
}

.sentence-item[data-speaker="question"] {
    background: rgba(59, 130, 246, 0.1);
    border-left: 4px solid #3b82f6;
    opacity: 0.9;
}

.sentence-item[data-speaker="participant"] {
    background: var(--bg-card);
    border-left: 4px solid #10b981;
}

.sentence-item[data-speaker="moderator"] {
    background: rgba(139, 92, 246, 0.1);
    border-left: 4px solid #8b5cf6;
    opacity: 0.9;
}

.speaker-badge {
    position: absolute;
    top: 8px;
    right: 8px;
    font-size: 0.7rem;
    font-weight: 600;
    text-transform: uppercase;
    padding: 2px 8px;
    border-radius: 4px;
    background: var(--bg-tertiary);
    color: var(--text-muted);
}
```

### B3. Split by Speaker Turn vs Sentence

**Recommendation: Hybrid approach**

1. **First pass**: Split by speaker turn (detect speaker label changes)
2. **Second pass**: Within each speaker turn, split by sentence
3. **Preserve grouping**: Store `turnId` to link sentences from same turn

**Rationale:**
- Speaker turns provide natural semantic boundaries
- Sentence splitting within turns allows fine-grained tagging
- UI can show "grouped" view (by turn) or "flat" view (by sentence)

**Data structure for turns:**
```javascript
excerpt: {
    // ...existing fields...
    turnId: string,          // Groups sentences from same speaker turn
    turnIndex: number,       // Position within the turn (0, 1, 2...)
    isTurnStart: boolean,    // First sentence in turn (show speaker label)
    isTurnEnd: boolean       // Last sentence in turn (add spacing)
}
```

### B4. Preserving Speaker Context When Tagging

**Context propagation rules:**
1. When an excerpt is created, store the most recent `task` text in `taskContext`
2. Store the most recent `question` text in `questionContext`
3. These fields are set at import time and remain static

**Implementation:**
```javascript
function parseTranscript(rawText, format) {
    let currentTask = null;
    let currentQuestion = null;
    let turnId = generateId();
    let currentSpeaker = null;

    const lines = rawText.split('\n');
    const excerpts = [];

    for (const line of lines) {
        const detected = detectSpeaker(line);

        if (detected.speakerType === 'task') {
            currentTask = detected.text;
            turnId = generateId();
        } else if (detected.speakerType === 'question') {
            currentQuestion = detected.text;
            turnId = generateId();
        } else if (detected.speakerType !== currentSpeaker) {
            turnId = generateId();
        }

        currentSpeaker = detected.speakerType;

        // Split into sentences
        const sentences = parseSentences(detected.text);

        for (let i = 0; i < sentences.length; i++) {
            excerpts.push({
                text: sentences[i],
                speakerType: detected.speakerType,
                speakerLabel: detected.speakerLabel,
                taskContext: currentTask,
                questionContext: currentQuestion,
                turnId: turnId,
                turnIndex: i,
                isTurnStart: i === 0,
                isTurnEnd: i === sentences.length - 1
            });
        }
    }

    return excerpts;
}
```

---

## C. One-Pager Export Format

### C1. Format Recommendation: HTML for Print

**Primary format: HTML**
- Self-contained single file
- Print-friendly CSS with `@media print`
- Can be opened in any browser
- Easy to copy/paste into other documents
- Can be converted to PDF via browser print dialog

**Alternative formats (future):**
- Markdown (for documentation/GitHub)
- DOCX (using a library like docx.js)
- PDF (direct generation with jsPDF)

### C2. HTML Template Structure

```html
<!DOCTYPE html>
<html>
<head>
    <title>Theme Report: {tagName}</title>
    <style>
        @page {
            margin: 1in;
            size: letter;
        }

        body {
            font-family: 'Georgia', serif;
            max-width: 7in;
            margin: 0 auto;
            padding: 40px;
            color: #1a1a2e;
            line-height: 1.6;
        }

        .report-header {
            border-bottom: 3px solid #6366f1;
            padding-bottom: 20px;
            margin-bottom: 30px;
        }

        .theme-name {
            font-size: 28px;
            font-weight: bold;
            color: #1a1a2e;
            margin: 0 0 10px 0;
        }

        .description {
            font-size: 16px;
            font-style: italic;
            color: #4a5568;
            margin: 20px 0;
            padding: 15px;
            background: #f7fafc;
            border-left: 4px solid #6366f1;
        }

        .summary {
            font-size: 14px;
            color: #718096;
            margin-bottom: 30px;
        }

        .excerpt-card {
            margin: 20px 0;
            padding: 20px;
            background: #fff;
            border: 1px solid #e2e8f0;
            border-radius: 8px;
            page-break-inside: avoid;
        }

        .participant-badge {
            display: inline-block;
            background: #10b981;
            color: white;
            padding: 2px 10px;
            border-radius: 4px;
            font-weight: bold;
            font-size: 12px;
            margin-bottom: 10px;
        }

        .excerpt-text {
            font-size: 16px;
            margin: 10px 0;
        }

        .excerpt-context {
            font-size: 13px;
            color: #718096;
            margin-top: 10px;
            padding-top: 10px;
            border-top: 1px solid #e2e8f0;
        }

        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #e2e8f0;
            font-size: 12px;
            color: #a0aec0;
            text-align: center;
        }

        @media print {
            body { padding: 0; }
            .excerpt-card { box-shadow: none; }
        }
    </style>
</head>
<body>
    <div class="report-header">
        <h1 class="theme-name">{tagName}</h1>
    </div>

    <div class="description">
        {tagDescription}
    </div>

    <div class="summary">
        <strong>{excerptCount} excerpts</strong> from
        <strong>{participantCount} participants</strong>
    </div>

    <div class="excerpts">
        <!-- Repeat for each excerpt -->
        <div class="excerpt-card">
            <span class="participant-badge">{speakerLabel}</span>
            <p class="excerpt-text">"{excerptText}"</p>
            <div class="excerpt-context">
                {taskContext && `Task: ${taskContext}`}
                {questionContext && `Question: ${questionContext}`}
                <br>
                Source: {transcriptTitle} (#{excerptIndex})
            </div>
        </div>
    </div>

    <div class="footer">
        Generated by QualCoder | {exportDate}
    </div>
</body>
</html>
```

### C3. Metadata to Include

| Metadata | Required | Source |
|----------|----------|--------|
| Theme/tag name | Yes | `tag.name` |
| Theme description | Yes | `tag.description` |
| Export date | Yes | Generated |
| Excerpt count | Yes | Calculated |
| Participant count | Yes | Count unique `speakerLabel` |
| Per-excerpt: speaker label | Yes | `excerpt.speakerLabel` |
| Per-excerpt: text | Yes | `excerpt.text` |
| Per-excerpt: task context | Optional | `excerpt.taskContext` |
| Per-excerpt: question context | Optional | `excerpt.questionContext` |
| Per-excerpt: source transcript | Optional | `transcript.title` |
| Per-excerpt: position | Optional | `excerpt.index` |

---

## D. Data Model Updates Summary

### D1. Current Model (from code analysis)

```javascript
// Current structure in localStorage
{
    transcripts: [{
        id: string,
        title: string,
        userLabel: string,
        rawText: string,
        createdAt: string,
        updatedAt: string
    }],
    excerpts: [{
        id: string,
        transcriptId: string,
        text: string,
        index: number,
        tagIds: string[],
        createdAt: string
    }],
    tags: [{
        id: string,
        name: string,
        usageCount: number,
        createdAt: string
    }]
}
```

### D2. Proposed Model

```javascript
{
    version: 2,  // Schema version for migrations

    transcripts: [{
        id: string,
        title: string,
        userLabel: string,           // e.g., "User 5", "P03"
        rawText: string,
        createdAt: string,
        updatedAt: string,
        // NEW:
        parseFormat: 'userlytics' | 'generic' | 'raw',
        participantLabels: string[], // Unique participants detected, e.g., ["P1", "P2"]
        taskCount: number,
        metadata: {                  // Extensible metadata
            platform: string,        // e.g., "Userlytics"
            testDate: string,
            duration: string
        }
    }],

    excerpts: [{
        id: string,
        transcriptId: string,
        text: string,
        index: number,              // Global index within transcript
        tagIds: string[],
        createdAt: string,
        // NEW:
        speakerType: 'task' | 'question' | 'participant' | 'moderator' | 'unknown',
        speakerLabel: string,       // e.g., "P1", "Task 2", "Q3", "Moderator"
        taskContext: string | null, // Most recent task text
        questionContext: string | null,  // Most recent question text
        turnId: string,             // Groups sentences from same speaker turn
        turnIndex: number,          // Position within turn (0, 1, 2...)
        timestamp: string | null,   // e.g., "01:45" if detected
        isTaggable: boolean         // Tasks/questions may be non-taggable
    }],

    tags: [{
        id: string,
        name: string,
        usageCount: number,
        createdAt: string,
        // NEW:
        description: string,        // 2-4 sentences about the theme
        color: string | null,       // Hex color for visual grouping
        updatedAt: string,
        // FUTURE:
        parentTagId: string | null, // For hierarchical tags
        synonyms: string[]          // Alternative names for search
    }]
}
```

### D3. Migration Strategy

```javascript
function migrateData(data) {
    if (!data.version || data.version < 2) {
        // Migrate excerpts
        for (const excerpt of data.excerpts) {
            excerpt.speakerType = excerpt.speakerType || 'unknown';
            excerpt.speakerLabel = excerpt.speakerLabel || '';
            excerpt.taskContext = excerpt.taskContext || null;
            excerpt.questionContext = excerpt.questionContext || null;
            excerpt.turnId = excerpt.turnId || excerpt.id;
            excerpt.turnIndex = excerpt.turnIndex || 0;
            excerpt.timestamp = excerpt.timestamp || null;
            excerpt.isTaggable = excerpt.isTaggable !== false;
        }

        // Migrate tags
        for (const tag of data.tags) {
            tag.description = tag.description || '';
            tag.color = tag.color || null;
            tag.updatedAt = tag.updatedAt || tag.createdAt;
        }

        // Migrate transcripts
        for (const transcript of data.transcripts) {
            transcript.parseFormat = transcript.parseFormat || 'raw';
            transcript.participantLabels = transcript.participantLabels || [];
            transcript.taskCount = transcript.taskCount || 0;
            transcript.metadata = transcript.metadata || {};
        }

        data.version = 2;
    }

    return data;
}
```

---

## E. Implementation Priority

### Phase 1: Foundation (Week 1)
**Goal: Enable tag descriptions and basic export**

| Task | Effort | Value | Priority |
|------|--------|-------|----------|
| E1.1 Add `description` field to tags | 2h | High | P0 |
| E1.2 Create tag description edit UI | 4h | High | P0 |
| E1.3 Show description preview in tag popover | 2h | Medium | P1 |
| E1.4 Data migration for existing tags | 1h | Critical | P0 |

**Deliverable:** Users can add/edit descriptions for tags

### Phase 2: Enhanced Export (Week 2)
**Goal: One-pager export for themes**

| Task | Effort | Value | Priority |
|------|--------|-------|----------|
| E2.1 Create HTML export template | 4h | High | P0 |
| E2.2 Add "Export One-Pager" button to Database view | 2h | High | P0 |
| E2.3 Export options dialog (include/exclude fields) | 3h | Medium | P1 |
| E2.4 Include tag description in export | 1h | High | P0 |

**Deliverable:** Users can export a formatted one-pager per theme

### Phase 3: Smart Parsing (Week 3-4)
**Goal: Auto-detect speaker turns on import**

| Task | Effort | Value | Priority |
|------|--------|-------|----------|
| E3.1 Implement speaker pattern detection | 6h | High | P0 |
| E3.2 Update excerpt data model | 2h | Critical | P0 |
| E3.3 Add visual distinction CSS for speaker types | 3h | High | P0 |
| E3.4 Add parse format selector to import modal | 2h | Medium | P1 |
| E3.5 Add "Preview Parsing" functionality | 4h | Medium | P1 |
| E3.6 Preserve task/question context | 3h | High | P0 |
| E3.7 Data migration for existing excerpts | 2h | Critical | P0 |

**Deliverable:** Transcripts are auto-parsed with speaker context preserved

### Phase 4: Refinement (Week 5)
**Goal: Polish and edge cases**

| Task | Effort | Value | Priority |
|------|--------|-------|----------|
| E4.1 Tags management view (list, edit, delete) | 4h | Medium | P1 |
| E4.2 Handle edge cases in parsing | 4h | Medium | P1 |
| E4.3 Add context info to export | 2h | Medium | P1 |
| E4.4 Toggle taggable/non-taggable for tasks | 2h | Low | P2 |
| E4.5 Speaker turn grouping view toggle | 4h | Low | P2 |

**Deliverable:** Polished experience with robust edge case handling

### Recommended Order

```
Week 1: E1.1 → E1.4 → E1.2 → E1.3
         (Tags get descriptions)

Week 2: E2.1 → E2.2 → E2.4 → E2.3
         (One-pager export works)

Week 3: E3.1 → E3.2 → E3.7 → E3.3 → E3.6
         (Smart parsing works)

Week 4: E3.4 → E3.5 → E4.1
         (Parsing polish, tag management)

Week 5: E4.2 → E4.3 → E4.4 → E4.5
         (Edge cases, nice-to-haves)
```

---

## F. Risks and Tradeoffs

### F1. Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Speaker detection accuracy on unusual formats | Medium | Medium | Provide manual override; fallback to raw mode |
| localStorage size limits (~5MB) | Low | High | Warn when approaching limit; offer export/archive |
| Data migration breaks existing data | Low | Critical | Backup before migration; version schema; test thoroughly |
| Pattern matching performance on large transcripts | Low | Low | Lazy parsing; limit preview to first 50 lines |

### F2. UX Tradeoffs

| Tradeoff | Option A | Option B | Recommendation |
|----------|----------|----------|----------------|
| Task/question taggability | Non-taggable (cleaner) | Taggable (more flexible) | Default non-taggable with toggle |
| Split granularity | By speaker turn | By sentence | Sentence (with turn grouping metadata) |
| Export format | HTML only | Multiple formats | HTML first, add markdown later |
| Tag descriptions | Required | Optional | Optional with prompts |

### F3. Scope Risks

| Risk | Mitigation |
|------|------------|
| Feature creep (hierarchical tags, etc.) | Strict scope for MVP; defer nice-to-haves |
| Over-engineering parsing | Start with Userlytics patterns only; add formats on demand |
| Spending too long on export formatting | Use simple, clean template; defer fancy styling |

### F4. Tradeoff Decisions

**Decision 1: Sentence vs Speaker Turn splitting**
- **Decision:** Split by sentence, but group by turn
- **Rationale:** Users need fine-grained tagging, but context matters
- **Implementation:** Store `turnId` to allow grouped display later

**Decision 2: Export format**
- **Decision:** HTML with print CSS
- **Rationale:** Maximum compatibility, easy to convert to PDF, no dependencies
- **Alternative considered:** Direct PDF generation (adds complexity, dependency)

**Decision 3: Speaker detection approach**
- **Decision:** Regex-based pattern matching
- **Rationale:** Simple, fast, maintainable; ML would be overkill
- **Alternative considered:** ML-based speaker diarization (too complex)

**Decision 4: Tag description storage**
- **Decision:** Free-form text field (2000 char limit)
- **Rationale:** Simplicity; rich text would complicate export
- **Alternative considered:** Markdown support (adds complexity)

---

## Appendix: Quick Reference

### New CSS Classes Needed

```css
.sentence-item[data-speaker="task"]
.sentence-item[data-speaker="question"]
.sentence-item[data-speaker="participant"]
.sentence-item[data-speaker="moderator"]
.speaker-badge
.speaker-badge--task
.speaker-badge--question
.speaker-badge--participant
.speaker-badge--moderator
.tag-description
.tag-description-input
.export-one-pager-btn
.tag-management-view
```

### New Functions Needed

```javascript
// Parsing
parseTranscript(rawText, format)
detectSpeaker(line)
extractTimestamp(line)
normalizeSpinnerLabel(raw)

// Tag Management
updateTagDescription(tagId, description)
renderTagManagementView()
deleteTag(tagId)  // with reassignment option

// Export
exportOnePager(tagId, options)
generateOnePagerHTML(tag, excerpts, options)
downloadHTML(content, filename)

// Migration
migrateData(data)
backupBeforeMigration()
```

### Keyboard Shortcuts to Add

| Shortcut | Action |
|----------|--------|
| `D` | Add/edit description for selected tag |
| `E` | Export one-pager (when tag is filtered) |
| `T` | Toggle view (sentence/turn grouping) |

---

## Summary

This gameplan provides a clear path to enhance QualCoder with:

1. **Tag descriptions** - Simple addition with high value for reporting
2. **One-pager export** - HTML-based reports per theme with context
3. **Smart transcript parsing** - Auto-detect Userlytics format speakers

The recommended approach is to build in phases, starting with tag descriptions (lowest risk, immediate value), then export (builds on descriptions), then parsing (most complex but transformative).

Total estimated effort: **~50-60 hours** over 4-5 weeks.
