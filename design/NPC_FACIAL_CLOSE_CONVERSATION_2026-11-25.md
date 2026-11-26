# NPC facial performance: the close conversation, 2026-11-25

Evidence class: **INERT**. This is a review report for Lily's work order **w8c788aec4db6** (facial
performance). It is not acceptance. The frames it cites are review evidence only, kept outside the repo in
C:/ov/reports/npc_face_20261125.

The facial audit (design/NPC_FACIAL_AUDIT_2026-11-24.md) left one item for this order to show rather than
build: a rebuilt resident in a close conversation, seen from where the player stands, at conversation
distance and close up. This branch adds a filmed test that does that. It changes no runtime script, no data
and no asset.

## 1. What the test does

game/tests/NpcCloseConversationShot.tscn (script npc_close_conversation_shot.gd) is windowed only. It writes
nothing headless.

- It builds one resident through the real presentation path, with its rebuilt body, face controller and
  speech hook. Then it opens that resident's own authored **ResidentConversations** tree on the real
  dialogue panel.
- The camera stands in front of the face at the player's eye. The test uses two framings: conversation,
  at 1.1 m with a 32° lens, and close, at 0.55 m with a 24° lens.
- Each line runs for 2.4 s and a frame is saved every 0.2 s. Then the first offered answer is chosen.
- Everything the face does comes from the runtime owners: attention, gaze and blinks, the mood reading
  and its gestures, and the speech hook's untimed jaw.
- When CUES_DIR holds a `<resident>__<node>.cues.json` for the line on the panel, the face mouths that
  file's timing in place of the jaw. No audio plays.
- Settings: RESIDENT (default cal_dwyer), LINES (default 4), SHOT_DIR and CUES_DIR.

## 2. Runs

All runs used the lane, the patched 4.7.1 engine and the hidden desktop, on branch
claude/npc-close-conversation.

| Run | Receipt | Result |
|---|---|---|
| compile2 | compile2.log.receipt.json | 1 script, 0 failures (the first compile caught an untyped Vector3, since fixed) |
| cal_shot2 | cal_shot2.log.receipt.json | exit 0; 96 frames; 2 lines mouthed from cue files; 0 failures |
| teresa_shot2 | teresa_shot2.log.receipt.json | exit 0; 84 frames; jaw fallback only; 0 failures |

Cal's cue files came from the voice pilot, C:/ov/reports/voice_dialogue_20261111/pilot_01/runtime. Only
his opening node, cd_open, has one, so that line is cued in both framings. Teresa has no cue files.

## 3. What the frames show

I looked at a contact strip of each line, in C:/ov/reports/npc_face_20261125/sheets.

**Working**

- **Cal's cued line.** The mouth closes and opens with the cue timing, and teeth show on the open vowels.
  It reads as speech at both distances.
- **Gaze settles onto the player.** The first frame of each conversation catches the head still turned
  away, and by the next it is facing the camera.
- **Blinks.** They arrive on the actor's own clock, mid-line and not in step with the mouth.
- **The jaw fallback.** On uncued lines it is restrained, and it is visible close up.
- **The mood reading.** Cal's frustration line (cd_nine) shows a tightened brow and narrowed eyes.

**Found; not fixed here**

These touch the cast's art, gestures and data. Per Lily's standing guidance on character behaviour, they
are reported, not changed.

1. **Teresa's sadness reads as drowsy.** On tv_knock (sadness, intensity 1.70) the lids sit half shut for
   the whole line, so at the close framing she looks asleep rather than sad. The intensity cap of 2 lets
   the reading push the eyes well past what the expression row was tuned at.
2. **The agree gesture looks like alarm.** On tv_prisoner the reading asked for agree_gesture, and her
   body threw both hands up beside her head with the fingers splayed. That is not a nod of agreement.
3. **A gesture from another resident's set.** On tv_knock the reading names the emote mina_strained, which
   is Mina's. The body did not play it, but the mood data offers it to Teresa.
4. **Cal's hair cards in close-up.** At 0.55 m a pale band of hair-card edges shows across the hairline
   whenever the head turns. It is invisible at conversation distance.
5. **The panel covers the chin up close.** At the close framing the dialogue panel covers the chin and the
   lower lip in a 4:3 window. This is a camera choice for this review. The game does not use that framing.
6. **One choice did not advance.** In Teresa's close run, tv_knock showed twice. Choosing the first
   offered answer did not move the panel on that node. This could come from the tree or from the panel,
   and it is not yet diagnosed.

## 4. Still owed on the order

- **Lip-sync to the speech that is actually playing.** This is blocked on runtime voice playback, which
  has another owner, and on Lily approving the recordings. The test proves that the cue path drives the
  face once a line has cues.
- **The closed-lid repair** (**w3de99b6b5013**) waits for the next cast re-export (ruling
  cast_lid_normals_20261124).
- **Findings 1 to 6 above** need owner rulings or a tuning pass. They are not part of this slice.
