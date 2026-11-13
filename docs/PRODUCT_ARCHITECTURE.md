# PillAI product architecture

## Product thesis

PillAI is not a generic medication chatbot. Its defensible product loop combines:

1. a persistent, structured medication and health record;
2. one-tap adherence events instead of repeated chat messages;
3. deterministic safety and scheduling constraints;
4. an assistant that explains known facts and missing coverage in plain language; and
5. visible, confirmable reminder-plan revisions only when a verified rule permits one.

## What the current brain really is

The runnable slice has two assistant layers:

- `DemoAssistantEngine` is an on-device deterministic router. It handles a finite emergency phrase set before networking, answers demo workflow questions, and supplies a safe fallback when the backend is unavailable.
- The optional Node backend can call the OpenAI Responses API with `gpt-5.6-terra`. The model is constrained to classify the question and select from a closed plan schema. The server then composes the user-facing reply from approved templates and the validated app context. Model text never directly changes a dose or reminder.

If `OPENAI_API_KEY` is absent, the same endpoint deliberately returns a labeled deterministic demo answer. The Flutter UI distinguishes live-model, backend-demo, local-fallback, and safety-guard sources. The backend and client contracts have automated coverage.

Voice is a real device input capability, not a separate medical brain. Speech becomes an editable transcript and is never sent or converted into a dose action without an explicit user action.

This architecture does **not** make the assistant clinically knowledgeable. There is no verified drug, label, interaction, pregnancy, allergy, organ-function, or dosing data source in this repository. Saved context improves the question; it never proves a combination is safe.

## Current request path

```text
User text or reviewed voice transcript
  -> local high-signal emergency gate
       -> urgent deterministic guidance; no model request
  -> explicit consent before remote health-context transfer
  -> typed Flutter request with bounded history and structured context
  -> loopback Node API validation and request-size limits
       -> no API key: labeled deterministic server demo
       -> API key: Responses API / gpt-5.6-terra
            -> strict closed AssistantPlan schema
            -> deterministic server-side reply composer
            -> output guard and source metadata
  -> per-answer source label in the app
```

The API key remains server-side. OpenAI requests use `store: false`, low reasoning effort for this latency-sensitive interaction, bounded inputs, and a privacy-preserving HMAC safety identifier rather than a raw health identifier.

## Safety context represented by the product

- Exact prescription, OTC, vitamin, mineral, herbal, and combination products
- Active ingredients copied from each label
- Allergies and past reactions
- Age range, weight context, pregnancy, breastfeeding, postpartum, and conception context
- Conditions plus kidney and liver health
- Meals, fasting, tea/coffee, dairy/calcium, grapefruit-family products, alcohol, vitamin-K patterns, potassium, fiber, and tube feeding
- Supplements, antacids, and other OTC products
- Smoking/nicotine, cannabis/CBD, travel, shift work, acute vomiting/diarrhea, and procedures
- Routine, actual dose history, accessibility needs, and caregiver involvement

These fields identify which questions require a more careful check. A recorded factor does not itself establish an interaction.

## Non-negotiable safety rules

- The assistant may explain, ask for missing facts, and route the user. It cannot prescribe.
- A language model never owns dose calculations, interaction truth, emergency triage, or final schedule validation.
- PillAI never changes dose, frequency, route, or treatment duration.
- A missed dose is an append-only event. The current build records it and leaves reminders unchanged because no verified product-specific missed-dose rules are connected.
- A future reminder proposal must cite an applicable versioned rule, show the before/after plan, and require confirmation.
- OCR or chat-extracted medication facts remain drafts until the user confirms exact product, active ingredient, strength, form, route, and label directions.
- Emergency gates interrupt ordinary chat and direct the user to local emergency or poison-center help. Finite keyword coverage is not a diagnosis and cannot prove that help was contacted.
- Unknown coverage remains visible. The app must not turn absence of evidence into reassurance.

## Recommended production shape

```text
Flutter app
  |-- encrypted local record and offline notification scheduler
  |-- append-only dose-event queue and sync
  `-- authenticated typed API client
          |
Application service
  |-- identity, consent, access control, and audit
  |-- medication and regimen records
  |-- immutable plan versions and dose events
  |-- deterministic schedule constraint engine
  |-- verified product/label/interaction adapters
  |-- deterministic emergency escalation
  `-- assistant orchestrator
          |
Assistant orchestrator
  |-- retrieves only consented relevant context
  |-- calls versioned verified tools
  |-- validates schema-constrained plans and proposed actions
  |-- attaches evidence, applicability, and uncertainty
  `-- requires explicit confirmation before every write
```

A modular backend with Postgres is sufficient for an MVP. Device reminders should remain local-first so they work offline. Store every planned and actual timestamp with an IANA timezone, and test daylight-saving transitions, travel, clock changes, and duplicate client retries.

## Core production records

- `UserProfile`: timezone, locale, routine, conditions, allergies, weight, consent versions
- `MedicationProduct`: normalized ingredient/product identity, strength, form, route, evidence source
- `UserMedication`: label image, directions, verification status, start/end dates
- `Regimen`: prescribed dose/frequency facts, kept separate from reminder preferences
- `Constraint`: meals, fasting, interval, daily maximum, or pairwise separation rule with source/version/applicability
- `PlanVersion`: immutable scheduled occurrences plus revision reason
- `DoseOccurrence`: one expected dose at one planned time
- `DoseEvent`: taken, missed, snoozed, or skipped with actual time, reason, and idempotency key
- `Alert`: severity, evidence, applicability, and acknowledgment state
- `AssistantMessage`: reply, source, coverage, citations, and schema-validated proposed actions
- `AuditLog`: user, system, rule, and model actions without hidden chain-of-thought

## Model and deterministic-tool split

The model may:

- interpret natural language and voice transcripts;
- identify the question category;
- select relevant saved context;
- ask for required missing facts;
- choose a safe, non-clinical next action; and
- explain structured tool results in plain language.

Deterministic or verified services must own:

- emergency escalation;
- medication/product identity;
- contraindications and interaction evidence;
- dose, maximum, and interval calculations;
- schedule constraint solving;
- plan writes and idempotency; and
- audit, authorization, and consent enforcement.

## Privacy and deployment boundary

The present backend is a local hackathon service. It binds to loopback by default and intentionally omits production identity and infrastructure. Public or multi-user deployment requires at least authentication, authorization, TLS termination, rate and concurrency limits, durable consent/audit records, encrypted storage, data-retention controls, monitoring, incident response, and a clinical/privacy review.

Never place an OpenAI key in Flutter, a mobile bundle, `--dart-define`, screenshots, logs, or source control.

## Build order after the hackathon slice

1. Persist and encrypt the structured record and append-only dose events.
2. Add real local notification scheduling and timezone-safe recurrence.
3. Normalize medication identity from user-confirmed labels or barcodes.
4. Integrate one licensed, versioned evidence source and expose its coverage.
5. Build deterministic constraint evaluation and immutable replan previews.
6. Add authentication, consent history, audit, abuse controls, and deletion/export.
7. Evaluate assistant classification, abstention, emergency routing, and provenance with clinician-reviewed cases.
8. Pilot with pharmacists and representative users before any clinical claim.
