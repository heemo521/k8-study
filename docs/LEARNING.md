# How people learn best — and what it means for k8-study

A short, evidence-based summary of learning science, then an audit of this app
against it and a ranked list of changes. The goal: every feature should exist
because it makes knowledge stick and transfer to the hands-on CKA exam.

## 1. What the research says

Ranked roughly by strength of evidence (Dunlosky et al., 2013 rated practice
testing and distributed practice "high utility"; most others "moderate").

| # | Principle | What it means | Key evidence |
|---|-----------|---------------|--------------|
| 1 | **Retrieval practice** (testing effect) | Pulling information *out* of memory strengthens it far more than re-reading it. Tests are a learning tool, not just a measure. | Roediger & Karpicke 2006; Karpicke & Blunt 2011; Dunlosky et al. 2013 |
| 2 | **Spacing** | Spread reviews over days, with growing gaps. Cramming feels better but is forgotten faster. Optimal gap ≈ 10–20% of how long you need to remember it. | Ebbinghaus 1885; Cepeda et al. 2006, 2008 |
| 3 | **Interleaving** | Mix related topics/problem types in one session instead of blocking one at a time. It trains *choosing* the right approach, which is what exams demand. | Rohrer & Taylor 2007; Kornell & Bjork 2008 |
| 4 | **Desirable difficulties** | Effort during learning (recall, generation, variation) slows short-term performance but improves long-term retention. Easy ≠ effective. | Bjork 1994; Bjork & Bjork 2011 |
| 5 | **Generation / pretesting** | Trying to answer *before* being taught (even wrongly) improves later learning — as long as feedback follows. | Slamecka & Graf 1978; Kornell, Hays & Bjork 2009; Richland et al. 2009 |
| 6 | **Elaboration & self-explanation** | Asking "why does this work?" and connecting it to what you know builds durable, transferable understanding. | Chi et al. 1994; Dunlosky et al. 2013 |
| 7 | **Feedback** | Immediate, specific feedback that explains *why* fixes errors; delayed feedback can aid retention once basics are known. Confident errors corrected stick best (hypercorrection). | Hattie & Timperley 2007; Butler & Roediger 2008; Butterfield & Metcalfe 2001 |
| 8 | **Worked examples → fading → solo practice** | Novices learn best from studied examples; as skill grows, remove steps until they solve alone (the *expertise-reversal* effect). | Sweller 1988; Renkl & Atkinson 2003; Kalyuga et al. 2003 |
| 9 | **Cognitive load & dual coding** | Working memory is small. Chunk content, cut extraneous detail, pair words with diagrams (not decoration). | Sweller 1988; Mayer 2009; Paivio 1986 |
| 10 | **Deliberate practice** | Targeted work on weaknesses, at the edge of ability, with fast feedback — not repeating what you already know. | Ericsson et al. 1993 |
| 11 | **Mastery learning** | Don't move on until a unit is mastered (~80–90%); correct gaps first. | Bloom 1968, 1984; Kulik et al. 1990 |
| 12 | **Metacognition / calibration** | Learners misjudge what they know; fluency (it *looks* familiar) is mistaken for mastery. Confidence ratings and honest scores fix this. | Koriat & Bjork 2005; Kornell & Bjork 2008 |
| 13 | **Transfer-appropriate processing** | Practise the way you'll be tested. CKA is hands-on in a terminal, so typing commands beats recognising them. | Morris, Bransford & Franks 1977 |
| 14 | **Sleep & short sessions** | Memory consolidates during sleep; several short sessions beat one long one. | Walker & Stickgold 2004; Cepeda et al. 2006 |

**Myths to avoid:** "learning styles" (matching visual/auditory learners has no
support — Pashler et al. 2008), highlighting and re-reading (low utility —
Dunlosky et al. 2013), and "I recognise it, so I know it".

### The core loop in one line

> **Try to recall → get specific feedback → space it out → mix it up →
> practise like the real test → focus on what's weak.**

## 2. Audit: how k8-study measures up

Status after the v1.2 changes (spec §14):

| Principle | Status | Where |
|-----------|--------|-------|
| Retrieval practice | ✅ Strong | Flashcards (flip before reveal), quizzes, practice tests, typed commands |
| Spacing | ✅ Strong | Leitner flashcards; wrong or unsure answers re-scheduled on the same intervals (§14.2) |
| Interleaving | ✅ Good | Today's review mixes due cards and questions across topics (§14.3); practice tests mix domains |
| Feedback | ✅ Good | Per-option explanations; confident mistakes called out (§14.1) |
| Metacognition | ✅ Good | Sure / Not sure on every answer; lucky guesses still count as gaps (§14.1) |
| Generation / pretesting | ✅ Good | Warm-up questions before a topic's notes (§14.6) |
| Self-explanation | ✅ Good | "Why is it right?" before explanations on harder questions (§14.7) |
| Worked examples → fading | ✅ Good | Guided labs: worked → partly guided → on your own (§14.8) |
| Transfer (hands-on) | 🟡 Better | Typed `kubectl` answers and labs (§14.5, §14.8); a real cluster is still needed for full practice |
| Deliberate practice | ✅ Good | Missed-first draws, gap plan, competency reviews |
| Mastery learning | ✅ Good | 80% mastery threshold, gap plan per competency |
| Dual coding | ✅ Good | Animated step-through diagrams |
| Cognitive load | ✅ Good | Structured note blocks, short sections |
| Short sessions & sleep | ✅ Good | 20-card cap; "next review tomorrow" nudges (§14.4) |
| Flashcard self-grading honesty | 🟡 Risk | "Got it" is still self-judged; the study guide below says to recall fully before flipping |

## 3. Recommendations (ranked by impact ÷ effort)

All eight are now implemented (spec §14.1–14.8). Kept here as the rationale.

1. **Typed-answer questions** *(transfer, generation — high impact)*. New
   question type `command`: the learner types a `kubectl`/YAML answer; graded by
   normalised match against accepted answers (flag order, short/long flags).
   Mixes into quizzes and practice tests. Closest thing to the real exam without
   a cluster.
2. **Confidence rating** *(metacognition, hypercorrection — low effort)*. After
   each answer: "Sure / Unsure". A correct-but-unsure answer counts as a gap;
   a wrong-but-sure answer is shown first in review. Store in answer history.
3. **Schedule missed questions** *(spacing)*. Reuse the Leitner engine for
   questions: a wrong answer re-enters review after 1 day, then 3, 7… "Reviews
   due" already exists on Progress — feed it from this.
4. **Interleaved daily review** *(interleaving + spacing)*. One "Today" session:
   due cards + due questions across all started topics, mixed. Make it the
   primary button on Home once a learner has started ≥2 topics.
5. **Pretest before notes** *(generation)*. Optional 3-question warm-up when a
   topic is opened for the first time; no score saved, answers revealed after
   reading.
6. **Guided labs with fading** *(worked examples → solo practice)*. Per topic,
   a scenario ("Expose Deployment `web` on port 80") shown three ways over time:
   full worked solution → partial with blanks → task only. Runs on the learner's
   own minikube/kind cluster; the app checks typed commands, not the cluster.
7. **"Why?" prompts** *(self-explanation)*. After a correct quiz answer on
   difficulty ≥2, occasionally ask the learner to pick the reason it's right
   from 3 options. Cheap to author from existing per-option explanations.
8. **Session nudges** *(spacing, sleep)*. Cap sessions (already 20 cards), show
   "come back tomorrow — N due" instead of encouraging marathon runs.

Items 1–4 cover the biggest gaps with the least new content and fit the current
engine design (pure Dart, injected `Clock`/`Random`, spec-driven). Each should
get a spec section (§14+) before code.

## 4. How to study with this app (for learners)

1. Open a topic → skim the **diagram** first, then read the **notes**.
2. Do the **flashcards**. Say the answer out loud *before* flipping. Only press
   "Got it" if you recalled it fully.
3. Take the **topic quiz**. Read every explanation, especially for ones you got right by guessing.
4. Next day: do **due cards** first, then start a new topic. Short daily
   sessions beat weekend marathons.
5. Every few topics: run a **mixed practice test**, then follow the **gap
   plan**.
6. Alongside all of it: type the commands in a real cluster (minikube/kind).
   Recognising `kubectl expose` is not the same as writing it under time.

## References

- Bjork, R. A. (1994). Memory and metamemory considerations in the training of human beings.
- Bjork, E. L., & Bjork, R. A. (2011). Making things hard on yourself, but in a good way.
- Bloom, B. S. (1984). The 2 sigma problem. *Educational Researcher*, 13(6).
- Butler, A. C., & Roediger, H. L. (2008). Feedback enhances the positive effects of multiple-choice testing. *Memory & Cognition*, 36.
- Butterfield, B., & Metcalfe, J. (2001). Errors committed with high confidence are hypercorrected. *JEP: LMC*, 27.
- Cepeda, N. J., et al. (2006). Distributed practice in verbal recall tasks. *Psychological Bulletin*, 132.
- Cepeda, N. J., et al. (2008). Spacing effects in learning: A temporal ridgeline. *Psychological Science*, 19.
- Chi, M. T. H., et al. (1994). Eliciting self-explanations improves understanding. *Cognitive Science*, 18.
- Dunlosky, J., et al. (2013). Improving students' learning with effective learning techniques. *Psychological Science in the Public Interest*, 14(1).
- Ericsson, K. A., Krampe, R. T., & Tesch-Römer, C. (1993). The role of deliberate practice. *Psychological Review*, 100.
- Hattie, J., & Timperley, H. (2007). The power of feedback. *Review of Educational Research*, 77.
- Kalyuga, S., et al. (2003). The expertise reversal effect. *Educational Psychologist*, 38.
- Karpicke, J. D., & Blunt, J. R. (2011). Retrieval practice produces more learning than elaborative studying with concept mapping. *Science*, 331.
- Koriat, A., & Bjork, R. A. (2005). Illusions of competence in monitoring one's knowledge during study. *JEP: LMC*, 31.
- Kornell, N., & Bjork, R. A. (2008). Learning concepts and categories: Is spacing the "enemy of induction"? *Psychological Science*, 19.
- Kornell, N., Hays, M. J., & Bjork, R. A. (2009). Unsuccessful retrieval attempts enhance subsequent learning. *JEP: LMC*, 35.
- Mayer, R. E. (2009). *Multimedia Learning* (2nd ed.).
- Morris, C. D., Bransford, J. D., & Franks, J. J. (1977). Levels of processing versus transfer appropriate processing. *JVLVB*, 16.
- Pashler, H., et al. (2008). Learning styles: Concepts and evidence. *Psychological Science in the Public Interest*, 9(3).
- Renkl, A., & Atkinson, R. K. (2003). Structuring the transition from example study to problem solving. *Educational Psychologist*, 38.
- Roediger, H. L., & Karpicke, J. D. (2006). Test-enhanced learning. *Psychological Science*, 17.
- Rohrer, D., & Taylor, K. (2007). The shuffling of mathematics problems improves learning. *Instructional Science*, 35.
- Slamecka, N. J., & Graf, P. (1978). The generation effect. *JEP: HLM*, 4.
- Sweller, J. (1988). Cognitive load during problem solving. *Cognitive Science*, 12.
- Walker, M. P., & Stickgold, R. (2004). Sleep-dependent learning and memory consolidation. *Neuron*, 44.
