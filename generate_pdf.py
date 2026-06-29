from fpdf import FPDF
import re

class DialoguePDF(FPDF):
    def __init__(self):
        super().__init__()
        self.set_auto_page_break(auto=True, margin=20)

    def header(self):
        if self.page_no() > 1:
            self.set_font("Helvetica", "I", 8)
            self.set_text_color(128, 128, 128)
            self.cell(0, 5, "If I Remember Correctly - Master Dialogue Document", align="C")
            self.ln(8)
            self.set_draw_color(200, 200, 200)
            self.line(10, self.get_y(), self.w - 10, self.get_y())
            self.ln(3)

    def footer(self):
        self.set_y(-15)
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(128, 128, 128)
        self.cell(0, 10, f"Page {self.page_no()}/{{nb}}", align="C")

    def title_page(self):
        self.add_page()
        self.ln(60)
        self.set_font("Helvetica", "B", 28)
        self.set_text_color(30, 30, 30)
        self.cell(0, 15, "IF I REMEMBER CORRECTLY", align="C")
        self.ln(20)
        self.set_font("Helvetica", "", 16)
        self.set_text_color(80, 80, 80)
        self.cell(0, 10, "Master Dialogue Document", align="C")
        self.ln(15)
        self.set_font("Helvetica", "I", 12)
        self.set_text_color(120, 120, 120)
        self.cell(0, 8, "A 2D Point-and-Click Adventure Game", align="C")
        self.ln(5)
        self.cell(0, 8, "Built in Godot 4", align="C")
        self.ln(25)
        self.set_draw_color(150, 150, 150)
        self.line(60, self.get_y(), self.w - 60, self.get_y())
        self.ln(15)
        self.set_font("Helvetica", "", 10)
        self.set_text_color(100, 100, 100)
        self.cell(0, 6, "This document contains all dialogue and story content from the game,", align="C")
        self.ln(6)
        self.cell(0, 6, "organized for comprehension by humans and language models alike.", align="C")
        self.ln(6)
        self.cell(0, 6, "Explicit content has been replaced with descriptive placeholders.", align="C")

    def section_header(self, text, level=1):
        self.ln(5)
        if level == 1:
            self.set_font("Helvetica", "B", 20)
            self.set_text_color(20, 60, 120)
            self.cell(0, 12, text)
            self.ln(8)
            self.set_draw_color(20, 60, 120)
            self.line(10, self.get_y(), self.w - 10, self.get_y())
            self.ln(6)
        elif level == 2:
            self.set_font("Helvetica", "B", 16)
            self.set_text_color(40, 80, 140)
            self.cell(0, 10, text)
            self.ln(8)
            self.set_draw_color(180, 200, 220)
            self.line(10, self.get_y(), self.w / 2, self.get_y())
            self.ln(4)
        elif level == 3:
            self.set_font("Helvetica", "B", 13)
            self.set_text_color(60, 100, 150)
            self.cell(0, 9, text)
            self.ln(7)
        elif level == 4:
            self.set_font("Helvetica", "BI", 11)
            self.set_text_color(80, 110, 150)
            self.cell(0, 8, text)
            self.ln(6)

    def dialogue_line(self, speaker, text, style="normal"):
        if style == "narrator":
            self.set_font("Helvetica", "I", 10)
            self.set_text_color(80, 80, 80)
            self.multi_cell(0, 5.5, f"[Narrator] {text}")
        elif style == "internal":
            self.set_font("Helvetica", "I", 10)
            self.set_text_color(100, 60, 100)
            self.multi_cell(0, 5.5, f"{speaker} (internal): {text}")
        elif style == "choice":
            self.set_font("Helvetica", "", 10)
            self.set_text_color(0, 100, 0)
            self.multi_cell(0, 5.5, f"  > CHOICE: {text}")
        elif style == "action":
            self.set_font("Helvetica", "I", 10)
            self.set_text_color(120, 100, 60)
            self.multi_cell(0, 5.5, f"[{text}]")
        elif style == "system":
            self.set_font("Helvetica", "B", 10)
            self.set_text_color(150, 50, 50)
            self.multi_cell(0, 5.5, f"[{text}]")
        else:
            self.set_font("Helvetica", "B", 10)
            self.set_text_color(30, 30, 30)
            speaker_w = self.get_string_width(f"{speaker}: ") + 2
            self.cell(speaker_w, 5.5, f"{speaker}: ")
            self.set_font("Helvetica", "", 10)
            self.set_text_color(50, 50, 50)
            remaining_w = self.w - self.l_margin - self.r_margin - speaker_w
            x_start = self.get_x()
            y_start = self.get_y()
            if self.get_string_width(text) > remaining_w:
                self.multi_cell(0, 5.5, text)
            else:
                self.cell(0, 5.5, text)
                self.ln(5.5)
        self.ln(1.5)

    def body_text(self, text):
        self.set_font("Helvetica", "", 10)
        self.set_text_color(50, 50, 50)
        self.multi_cell(0, 5.5, text)
        self.ln(2)

    def italic_text(self, text):
        self.set_font("Helvetica", "I", 10)
        self.set_text_color(80, 80, 80)
        self.multi_cell(0, 5.5, text)
        self.ln(2)

    def table_row(self, col1, col2, header=False):
        col1_w = 55
        col2_w = self.w - self.l_margin - self.r_margin - col1_w
        y_before = self.get_y()

        if header:
            self.set_font("Helvetica", "B", 10)
            self.set_text_color(255, 255, 255)
            self.set_fill_color(60, 90, 140)
        else:
            self.set_font("Helvetica", "", 9)
            self.set_text_color(50, 50, 50)
            self.set_fill_color(245, 245, 250)

        x = self.get_x()
        self.multi_cell(col1_w, 5, col1, fill=True)
        h1 = self.get_y() - y_before

        self.set_xy(x + col1_w, y_before)
        if not header:
            self.set_font("Helvetica", "", 9)
        self.multi_cell(col2_w, 5, col2, fill=True)
        h2 = self.get_y() - y_before

        final_y = y_before + max(h1, h2)
        self.set_y(final_y)
        self.ln(0.5)


def build_pdf():
    pdf = DialoguePDF()
    pdf.alias_nb_pages()

    # Title page
    pdf.title_page()

    # TABLE OF CONTENTS
    pdf.add_page()
    pdf.section_header("TABLE OF CONTENTS", 1)

    toc_items = [
        ("PART 1: MAIN STORY", [
            "1.1 Game Overview & Characters",
            "1.2 Intro Sequence (Dream/Void)",
            "1.3 AIda - First Meeting",
            "1.4 AIda - Hub Conversations",
            "1.5 McBucket / Old Man - All States",
            "1.6 Sergey - Full Conversation",
            "1.7 Memory Box & Insurance Form",
            "1.8 Dev CTA / End of Demo",
        ]),
        ("PART 2: INTERACTION DIALOGUE", [
            "2.1 Examine Responses",
            "2.2 Talk To Responses",
            "2.3 Pick Up Responses",
            "2.4 Use Responses",
            "2.5 Give Responses",
            "2.6 Flash Responses",
        ]),
        ("PART 3: ENVIRONMENTAL & PUZZLE", [
            "3.1 Toilet Puzzle Chain",
            "3.2 Progression Gates",
            "3.3 Hint System",
        ]),
        ("APPENDIX", [
            "A. Critical Path Walkthrough",
            "B. Miscellaneous & Debug Files",
        ]),
    ]

    for part_title, items in toc_items:
        pdf.set_font("Helvetica", "B", 12)
        pdf.set_text_color(30, 30, 30)
        pdf.cell(0, 8, part_title)
        pdf.ln(8)
        for item in items:
            pdf.set_font("Helvetica", "", 10)
            pdf.set_text_color(80, 80, 80)
            pdf.cell(10)
            pdf.cell(0, 6, item)
            pdf.ln(6)
        pdf.ln(4)

    # ============================================================
    # PART 1: MAIN STORY
    # ============================================================
    pdf.add_page()
    pdf.section_header("PART 1: MAIN STORY (Chronological)", 1)
    pdf.body_text("The main story follows this critical path: Intro dream sequence -> Talk to AIda -> Try MemoryBox (locked) -> Talk to Sergey (learn about TechPass) -> Clog toilet (distraction) -> Steal medicine -> Drug McBucket with Zanopram -> Return to Sergey -> Obtain TechPass -> Use MemoryBox -> Fill insurance form -> Exit")

    # 1.1 OVERVIEW
    pdf.section_header("1.1 Game Overview & Characters", 2)
    pdf.body_text('"If I Remember Correctly" is a 2D point-and-click adventure game set in a near-future hospital run by HAVEMORE Inc, a mega-corporation that manages American infrastructure. The player controls a female protagonist who wakes up with complete amnesia in a hospital ward. She must recover her identity by using a MemoryBox device, which requires a TechPass she doesn\'t have.')
    pdf.body_text('The game explores themes of memory, identity, corporate control, depression, and human connection through a verb-based interaction system (examine, talk to, pick up, use, give, flash).')

    pdf.section_header("Characters", 3)
    chars = [
        ("Player (Fiona)", "The protagonist. A woman who wakes from a coma with no memories. Resourceful, witty, manipulative when needed. Name discovered through the MemoryBox."),
        ("AIda", "AI nurse (Assigned Intelligence for Diagnostic Assistance). Corporate-friendly speech. Metallic limbs, nurse attire. Manages the ward."),
        ("Sergey", "Russian man, mid-forties. Former HAVEMORE Defense research contractor. Had a heart attack. Kind, lonely, widowed. The player manipulates him emotionally to obtain his TechPass."),
        ("McBucket / Old Man (Patient #67)", 'Elderly patient who screams "REEEEE" by default. Responds differently to three medications: Cannathink (philosophical stoner), Invigirol (screams louder), Zanopram (falls asleep).'),
        ("Dread", "Purple entity in the intro. Represents depression and the desire to give up."),
        ("Hope", "Pink entity in the intro. Represents the will to continue living."),
        ("Lewgend", "The game's developer. Fourth-wall-breaking end-of-demo scene."),
        ("Layla", "Female love interest teased at end of demo."),
        ("Malcolm", "Male love interest teased at end of demo (still using template sprite)."),
        ("CEO Voss", "Head of HAVEMORE Inc. Brief TV appearance."),
    ]
    for name, desc in chars:
        pdf.set_font("Helvetica", "B", 10)
        pdf.set_text_color(30, 30, 30)
        w = pdf.get_string_width(f"{name}: ") + 2
        pdf.cell(w, 5.5, f"{name}: ")
        pdf.set_font("Helvetica", "", 10)
        pdf.set_text_color(60, 60, 60)
        pdf.multi_cell(0, 5.5, desc)
        pdf.ln(2)

    pdf.section_header("Setting", 3)
    pdf.body_text("A HAVEMORE Inc Multispecialty Recovery Facility in the Greendale precinct. Playable areas: a hospital room (player's bed, Sergey's bed, McBucket's corner, medicine cabinet, MemoryBox, TV, exit door) and a connected bathroom (toilet, mirror, toilet paper dispenser).")

    pdf.section_header("Items", 3)
    items = [
        ("Zanopram", "Sleep medication. Used on McBucket's medicine dispenser to put him to sleep."),
        ("Cannathink", "Makes McBucket enter a philosophical 'high' state."),
        ("Invigirol", "Makes McBucket scream even more aggressively."),
        ("Hospital Toilet Paper", "Thick premium toilet paper. Used to clog the toilet (creating a distraction)."),
        ("Rusty Key", "A collectible key item."),
        ("TechPass", "Sergey's HAVEMORE access card. Needed to unlock the MemoryBox."),
    ]
    for name, desc in items:
        pdf.set_font("Helvetica", "B", 10)
        pdf.set_text_color(30, 30, 30)
        w = pdf.get_string_width(f"{name}: ") + 2
        pdf.cell(w, 5.5, f"{name}: ")
        pdf.set_font("Helvetica", "", 10)
        pdf.set_text_color(60, 60, 60)
        pdf.multi_cell(0, 5.5, desc)
        pdf.ln(1)

    # 1.2 INTRO
    pdf.add_page()
    pdf.section_header("1.2 Intro Sequence", 2)
    pdf.italic_text("Source: dialogue/intro.dialogue")
    pdf.italic_text("The game opens in complete darkness. The player is submerged in an abstract void.")
    pdf.ln(3)

    pdf.dialogue_line("Narrator", "A darkness folds over you like a sea. You wake up to nothing. You see nothing. You hear nothing. You feel nothing. The sea of Dark is vast and heavy. You sink under its pressure. Going back to sleep wouldn't be so bad. Would it? It's what you wanted originally, anyway.", "narrator")
    pdf.dialogue_line("", '"Go to sleep" / "Struggle against the darkness"', "choice")
    pdf.ln(2)

    pdf.italic_text("If the player chooses to sleep:")
    pdf.dialogue_line("Narrator", "Your body feels heavier. It's comforting. You'd like this. The darkness is enticing. There's no uncertainty to it. It just... is. And you're in it. Are you sure you want to sleep?", "narrator")
    pdf.dialogue_line("", '"I\'m sure. Goodnight." [GAME OVER] / "No. I must continue."', "choice")
    pdf.ln(2)

    pdf.italic_text("If the player continues, they encounter Dread:")
    pdf.dialogue_line("Narrator", "You cut through still water. Something stirs. You come across Dread. Somehow, this doesn't feel like a discovery to you.", "narrator")
    pdf.dialogue_line("Dread", "Hello, friend. It's been a while, hasn't it? You've been asleep for some time, too. Why don't you go back to sleep again? It's easier down there. See nothing. Hear nothing... feel nothing. It saves us so much pain. Come, I'll help you sleep again.")
    pdf.dialogue_line("", '"Okay. I\'ll sleep." / "No. I don\'t want to sleep again."', "choice")
    pdf.ln(2)

    pdf.italic_text("If the player refuses:")
    pdf.dialogue_line("Dread", "But... whyyyyyy? You desolate pup. He left. She died. Ain't nobody looking out for Little Miss Melancholy. You. Don't. Wanna. Wake up. Go back to sleep, friend. Come, enter eternal slumber with me.")
    pdf.dialogue_line("", '"Okay, fine. I\'ll sleep." [GAME OVER] / "Leave Dread behind and swim away."', "choice")
    pdf.ln(2)

    pdf.italic_text("If the player leaves Dread:")
    pdf.dialogue_line("Narrator", "You decide to leave Dread alone and venture further into the vast ocean. But the pressure doesn't lessen. The dark stretches on endlessly. Not the faintest glimmer of light is close to you. You've been swimming a while now. Your limbs burn.", "narrator")
    pdf.dialogue_line("Narrator", "You begin to wonder what it would be like to... rest. To truly rest. To no longer be a slave to the human condition. To no longer want. To no longer need. No longer feel. What do you do next?", "narrator")
    pdf.dialogue_line("", '"Lay to eternal rest." [GAME OVER] / "Just... keep... pushing..."', "choice")
    pdf.ln(2)

    pdf.italic_text("If the player keeps pushing:")
    pdf.dialogue_line("Narrator", "If anyone were watching you right now, they'd commend your bravery. Sadly, bravery doesn't amount to much here. You've pushed as hard as you can, but your body finally begins to give out. You're still now. You can't press on anymore. You begin to sink.", "narrator")
    pdf.dialogue_line("Narrator", '"This is good," you think to yourself. You tried your best. You tried your be---!!! Suddenly -- a warm presence grabs your hand.', "narrator")
    pdf.dialogue_line("Hope", "I'm sorry it took me this long.")
    pdf.dialogue_line("Narrator", "Late as always, it seems Hope finally found you.", "narrator")
    pdf.dialogue_line("Hope", "It's okay, love. Breathe. Just breathe.")
    pdf.dialogue_line("Narrator", "Instinct screams against it. Breathe in when you're sinking in this heavy ocean? However, something in Hope's voice compels you. You relax... and take a deep, shuddering breath.", "narrator")
    pdf.dialogue_line("Hope", "It's okay. You're okay.")
    pdf.dialogue_line("Narrator", "Around you, something changes. You see a singular ray of light in the far distance. But it's so far away. You think you'll never reach it. Suddenly, Hope wraps you in her warmth. You begin your journey toward the light.", "narrator")
    pdf.dialogue_line("Hope", "This is gonna take us a while, you know. But we got this. Just hold on. Just hold on.")
    pdf.dialogue_line("Narrator", "Well, would you look at that... The dark folds over you like a sea. But something in you still floats!", "narrator")
    pdf.dialogue_line("Hope", "First, we need to see the Nurse.")
    pdf.dialogue_line("Narrator", 'The darkness around you starts to thin, replaced by faint, unfamiliar sensations... "The Nurse?" you think to yourself. "What nurse?" Regardless of your worries, you continue to float upward, held warmly by Hope. Welcome back.', "narrator")

    # 1.3 AIda First Meeting
    pdf.add_page()
    pdf.section_header("1.3 AIda - First Meeting", 2)
    pdf.italic_text("Source: AIda.dialogue")
    pdf.italic_text("The player approaches AIda in the hospital room for the first time.")
    pdf.ln(3)

    pdf.dialogue_line("Narrator", "A woman in a Nurse's attire is busy at work. She notices you approaching before you could call for her.", "narrator")
    pdf.dialogue_line("AIda", "Oh, patient #122! You're finally awake. That is statistically encouraging! Welcome back to the waking world!")
    pdf.dialogue_line("", '"Where am I?"', "choice")
    pdf.dialogue_line("AIda", "You are currently located at HAVEMORE Inc's Multispecialty Recovery Facility - Greendale Avenue branch. Congratulations! You're receiving the most advanced care legally permitted in this precinct. I am AIda - Assigned Intelligence for Diagnostic Assistance! But you can just call me AIda.")
    pdf.dialogue_line("", '"Condition? What Condition?"', "choice")
    pdf.dialogue_line("AIda", "You were found unconscious on Christie Street. We couldn't determine a definite cause through our preliminary scans. Can you recall what happened?")
    pdf.dialogue_line("", '"I can\'t. I don\'t remember a thing!" / "I can\'t even recall my name."', "choice")
    pdf.dialogue_line("AIda", "Oh no. That's... quite unfortunate. Cognitive impairment is not uncommon in cases like yours. But don't worry - HAVEMORE Inc is fully committed to restoring you to optimal operating status. Patient #122, can you try recalling your name for me?")
    pdf.italic_text("The player tries but draws a blank.")
    pdf.dialogue_line("AIda", "Memory loss confirmed. Would you be willing to consent to a non-invasive HAVEMORE Inc Neural Integrity Scan? I can do it on the spot. It will allow us to see if you've suffered any major injuries in the regions of the brain associated with semantic and episodic memories.")
    pdf.dialogue_line("", '"How much will it cost me?" / "No, thanks."', "choice")
    pdf.ln(2)

    pdf.italic_text("If player asks about cost:")
    pdf.dialogue_line("AIda", "$2000. The amount will be automatically billed to your insurance provider. ... Assuming we can locate one.")
    pdf.dialogue_line("Player", "I don't like the sound of that.", "internal")
    pdf.dialogue_line("", '"How much have I incurred till now?"', "choice")
    pdf.dialogue_line("AIda", "Approximately $546,780.")
    pdf.dialogue_line("Narrator", "A shiver runs down your spine. You may not remember who you are, but you know in your bones that amount's a problem.", "narrator")
    pdf.dialogue_line("AIda", "But good news! If you're properly insured, your out-of-pocket cost might be as low as $20,000 USD! The problem is... there was no phone, wallet, ID, or wearable device found on your person at intake. In short - to access your insurance, we need to know who you are. And to know who you are... well, we need access to your memories. That's why I recommend proceeding with the Neural Integrity Scan. It's your best chance to... reconnect with yourself.")
    pdf.ln(2)

    pdf.section_header("The Neural Integrity Scan", 4)
    pdf.dialogue_line("AIda", "Splendid! Beginning scan in 3, 2, 1...")
    pdf.dialogue_line("Narrator", "The Nurse places her metallic hands on your temple. She feels as cold as a spoon in a refrigerator. Her irises shift to gray, then pulse red. A soft vibration hums through your skull.", "narrator")
    pdf.dialogue_line("AIda", "Progress: 4%... 22%... 67%... 91%... Scan complete. Thank you patient #122. Unfortunately, findings indicate substantial damage to your hippocampus and left temporal lobe. That would explain your current inability to access long-term autobiographical memory.")
    pdf.dialogue_line("AIda", "Fortunately! HAVEMORE Inc now offers proprietary MemoryBox therapy - a revolutionary tool for memory stimulation and reconstruction. Luckily, we have a MemoryBox installed right here in this very unit. You may find it towards the right.")
    pdf.dialogue_line("", '"How do I use this MemoryBox?"', "choice")
    pdf.dialogue_line("AIda", "Excellent question! Think of it as... guided lucid dreaming, but clinically supervised. You'll relive the memory as if you're there again. HAVEMORE Inc assures all patients that the process is perfectly safe! Though I should mention: some find the experience disorienting at first.")
    pdf.dialogue_line("", '"Fine, I\'ll check it out. [Leave]"', "choice")
    pdf.dialogue_line("AIda", "Splendid! Here, I am providing you with this tablet.")
    pdf.dialogue_line("", "Notification: Insurance Form Added!", "system")
    pdf.dialogue_line("AIda", "Once you piece your memory together using the MemoryBox, fill out your personal details in the insurance form open in the tablet. Doing so ensures HAVEMORE Inc can verify your identity and reconnect you with your coverage plan. More importantly - it'll prevent your current balance from being transferred to our Collections Department. Consider it your lifeline back to solvency! The more complete your profile, the faster we can process your claim. ... and the lower your personal liability becomes.")

    # 1.4 AIda Hub
    pdf.add_page()
    pdf.section_header("1.4 AIda - Hub Conversations", 2)
    pdf.italic_text("After the first meeting, the player can return to AIda for additional topics.")
    pdf.ln(3)

    pdf.dialogue_line("AIda", "Patient #122! Welcome back! How can I help you?")
    pdf.ln(2)

    pdf.section_header('"What happened to me?"', 4)
    pdf.dialogue_line("AIda", "As I mentioned earlier, you were found unconscious on Christie Street thirteen days ago. A passerby reported the incident while out for a walk, and our emergency responders brought you here shortly afterward. The team found nothing on you, except for an old journal. I highly recommend using the MemoryBox in order to recover your memories.")
    pdf.ln(2)

    pdf.section_header('"What is this place?" -> "What\'s a Havemore?"', 4)
    pdf.dialogue_line("AIda", "Havemore is America's number one administrative and tech partner. Our systems support healthcare, logistics, and urban management across the country. Ever since entering into a partnership with Havemore, America has seen a 150% increase in its GDP!")
    pdf.dialogue_line("Player", "So like, are there no poor people now?")
    pdf.dialogue_line("AIda", "Economic growth has significantly improved national prosperity. However, individual financial outcomes may vary. Havemore remains determined to make America a better experience for all residents.")
    pdf.ln(2)

    pdf.section_header('"What is this place?" -> "Precinct?"', 4)
    pdf.dialogue_line("AIda", "Indeed! All cities in America are divided into Havemore administered precincts. We are currently in the Greendale precinct's medical facility.")
    pdf.ln(2)

    pdf.section_header('"The MemoryBox seems to be locked."', 4)
    pdf.italic_text("Requires: player has tried the MemoryBox")
    pdf.dialogue_line("AIda", "Oh! I'm terribly sorry about that! I must have forgotten to mention that access to a MemoryBox requires a HAVEMORE TechPass. You might not remember, but it is a crucial part of everyday life now. All public technology systems require a registered TechPass for access. No terminals, no dispensers, no doors that scan ID.")
    pdf.dialogue_line("AIda", "It appears you do not currently have one assigned to you. But please don't worry! I will submit a request for HAVEMORE to issue you a temporary pass. Everything will be taken care of. However... I should mention that temporary passes usually take about 30 days to arrive. Until then, your medical expenses will continue accumulating on a daily basis.")
    pdf.dialogue_line("Player", "No way I'm staying here 30 more days!")
    pdf.dialogue_line("AIda", "I completely understand your concern. Unfortunately, without a TechPass, access to public systems is not possible.")
    pdf.dialogue_line("Player", "Yeah. That's not happening. I've got to find another way to start that damned box. No way I'm staying here another day.", "internal")
    pdf.ln(2)

    pdf.section_header('"What\'s wrong with the Old Man?"', 4)
    pdf.italic_text("Requires: McBucket has screamed at player")
    pdf.dialogue_line("AIda", "Oh! You mean Patient #67. He has been with us for quite some time. Our medical specialists are still researching his condition. But rest assured - Patient #67 is completely harmless! When given the correct treatment, he can even become quite talkative.")
    pdf.dialogue_line("Player", "How do I shut him up?")
    pdf.dialogue_line("AIda", "While Patient #67 is usually quiet, he does scream from time to time. This tends to happen when he sees something... overly exciting. That is why we keep the television in front of him tuned to HAVEMORE News! Slow and predictable programming helps keep him calm. However, this method is not 100% effective.")
    pdf.dialogue_line("Player", "Any medicine to help him sleep?")
    pdf.dialogue_line("AIda", "Why yes! Patient #67 is also receiving treatment for insomnia. We do administer sleep medication when necessary. However, it is currently outside his scheduled dosage time. If his screaming is bothering you, I recommend avoiding any... exciting activity near him.")
    pdf.dialogue_line("Player", "So they do have meds for him. And they're probably kept somewhere in this room. I should look around.", "internal")
    pdf.ln(2)

    pdf.section_header('"About the Old Man..." (after McBucket drugged)', 4)
    pdf.dialogue_line("Narrator", "AIda glances over at Patient #67.", "narrator")
    pdf.dialogue_line("AIda", "Oh! It seems Patient #67 has fallen asleep on his own today. That's unusual. He rarely does that without his medication - especially at this hour. We'll likely need to monitor this more closely.")
    pdf.dialogue_line("Player", "Looks like she didn't notice your little slip. Good.", "internal")

    # 1.5 McBucket
    pdf.add_page()
    pdf.section_header("1.5 McBucket / Old Man - All States", 2)
    pdf.italic_text("Source: mcbucket_unified.dialogue")
    pdf.ln(3)

    pdf.section_header("DEFAULT STATE (untreated)", 3)
    pdf.dialogue_line("Narrator", "An ancient man stares at you intently. Or at least, you think. The squint makes it hard to tell.", "narrator")
    pdf.italic_text("No matter what the player says, McBucket responds the same:")
    pdf.dialogue_line("Old Man", "REEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE~~~~~!!!")
    pdf.italic_text("The player can scream back, leading to an infinite screaming loop.")
    pdf.ln(3)

    pdf.section_header("HIGH STATE (after Cannathink)", 3)
    pdf.dialogue_line("Narrator", "An ancient man leans back in his hospital chair. The squint in his eyes seems to have relaxed.", "narrator")
    pdf.dialogue_line("Player", "Hey, how are you?")
    pdf.dialogue_line("Old Man", "I...am. Yes.")
    pdf.dialogue_line("Player", "Excuse me?")
    pdf.dialogue_line("Old Man", "I would never accuse you of anything, friend. I think you are just... splendid.")
    pdf.dialogue_line("Player", "Nice eyes, Old Man.")
    pdf.dialogue_line("Old Man", "Thanks! Got 'em from my sister's side of the family, I think.")
    pdf.dialogue_line("Player", "Your... sister's side?")
    pdf.dialogue_line("Old Man", "Hehehe... Yeah. She's got great knees too. That woman.")
    pdf.ln(2)
    pdf.dialogue_line("Player", "Tell me something about yourself. What's your name?")
    pdf.dialogue_line("Old Man", "Sure! Do you wanna know my worldly name... or my real name?")
    pdf.dialogue_line("Player", "Your worldly name.")
    pdf.dialogue_line("Old Man", "That would be... Mr. Turtle.")
    pdf.dialogue_line("Player", "Mr. Turtle?")
    pdf.dialogue_line("Old Man", "Yes. I rarely come outta my shell. And I swim. I always swim.")
    pdf.dialogue_line("Player", "Okay... what's your real name then?")
    pdf.dialogue_line("Old Man", "That would be... Love.")
    pdf.dialogue_line("Player", "Love? What do you mean?")
    pdf.dialogue_line("Old Man", "I mean the only real thing in this world is love. Say, kid... you ever loved anyone before?")
    pdf.ln(2)
    pdf.italic_text("If yes:")
    pdf.dialogue_line("Old Man", "Hah! Then you already know what I'm talking about! Hold onto it, kid. It's rarer than a polite seagull. And when you find it again... feed it something nice.")
    pdf.italic_text("If no:")
    pdf.dialogue_line("Old Man", "Then I hope it finds you soon! It's the most wonderful thing. Once you're in love... you see it everywhere. In the grass. In the tiles. On the screen. Even in the chips.")
    pdf.dialogue_line("Player", "The chips?")
    pdf.dialogue_line("Old Man", "Yeah. You got any on ya? I'm gettin' kinda hungry for some reason.")
    pdf.ln(2)
    pdf.dialogue_line("Player", "Have you ever been in love?")
    pdf.dialogue_line("Old Man", "Who? Me? I am always in love. It's not possible for me to not be in it. I only forget sometimes.")
    pdf.dialogue_line("Old Man", "Once, I was walking down the street, and this RoboCop comes up to me and says... ... Wait -- what was I talking about?")
    pdf.ln(2)
    pdf.italic_text("If the player mentions having no memories:")
    pdf.dialogue_line("Old Man", "Oh boy, no memories huh? Who took 'em from ya? Did you check the fridge? Don't worry kiddo. Maybe they are just out for a swim. Maybe one day they'll swim right back to ya.")
    pdf.ln(3)

    pdf.section_header("INVIGIROL STATE", 3)
    pdf.italic_text("McBucket screams endlessly without stopping. An infinite loop.")
    pdf.dialogue_line("Old Man", "REEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE~~~~~!!!")
    pdf.ln(3)

    pdf.section_header("SLEEPING STATE (after Zanopram)", 3)
    pdf.dialogue_line("Narrator", "The Old Man is fast asleep.", "narrator")

    # 1.6 SERGEY
    pdf.add_page()
    pdf.section_header("1.6 Sergey - Full Conversation", 2)
    pdf.italic_text("Source: sergey_dialogue_1.dialogue")
    pdf.italic_text("NOTE: This conversation contains an intimate scene. Explicit content has been replaced with descriptive placeholders marked in [brackets].")
    pdf.ln(3)

    pdf.dialogue_line("Narrator", "A man in his mid-forties sits upright on his bed. His sharp eyes track you as you stir. He looks Slavic.", "narrator")
    pdf.dialogue_line("Sergey", "Ah. You wake. Good. Was not sure you ever would. So then... tell me. How can Sergey help?")
    pdf.ln(2)

    pdf.section_header('"How long was I out?"', 4)
    pdf.dialogue_line("Sergey", "Hard to say. You sleep long time. Since I arrive here, you do not move. Like statue.")
    pdf.dialogue_line("Player", "I can't recall anything.")
    pdf.dialogue_line("Sergey", "Hm. That is... not good. You truly remember nothing?")
    pdf.dialogue_line("Player", "Nope. Nothing at all.")
    pdf.dialogue_line("Sergey", "Then maybe this is fresh start, da? Clean page. In Russia we say... sometimes forgetting is gift.")
    pdf.ln(2)

    pdf.section_header('"Who are you?"', 4)
    pdf.dialogue_line("Sergey", "Name is Sergey. Heart had attack, so now I sit here. Happen right before I was about to leave the country, too. Bad timing.")
    pdf.dialogue_line("Player", "Leaving? Where to?")
    pdf.dialogue_line("Sergey", "Home. Russia. Before this, I was research contractor for HAVEMORE Defense. Not soldier - I worked with machines. Autonomous systems... behavior models... things that are supposed to make security 'more efficient'.")
    pdf.dialogue_line("Sergey", "Is funny. Work was not dangerous, but somehow... still hurts the head. The heart too, maybe.")
    pdf.dialogue_line("Player", "Stressful job?")
    pdf.dialogue_line("Sergey", "Hm. Stressful... yes. Very quiet type of stress. Too many screens. Too many decisions that are not really decisions. People there burn out without fire.")
    pdf.dialogue_line("Sergey", "Anyway... I told my manager I bring resignation letter next day. Felt lighter than I had in years. Finally, I could go home, see snow, maybe drink tea with my little sister.")
    pdf.dialogue_line("Sergey", "That night -- boom. Heart decides to protest. HAVEMORE doctors saved me, da. But their insurance only works if I am still employee. If I quit now... bills will finish me faster than heart ever tried.")
    pdf.dialogue_line("Sergey", "So I stay. At least until I can stand without that Nurse Bot helping me up.")
    pdf.dialogue_line("Player", "I'm so sorry to hear that.")
    pdf.dialogue_line("Sergey", "Eh. No need for sorry. Life is... how you say... stubborn. It goes where it wants. I just follow for now. But enough about Sergey. What about you, hm?")
    pdf.ln(2)

    pdf.section_header('"How can I use the MemoryBox?"', 4)
    pdf.italic_text("Requires: has spoken to AIda, tried MemoryBox, learned Sergey's identity")
    pdf.dialogue_line("Sergey", "That machine? Simple. Just put in your TechPass, turn the machine on, and put your hand on the scanner. Boom, you can access your memories. I tried once. Helps if you feel lost or... Lonely. But I do not look backward anymore. Only forward.")
    pdf.dialogue_line("Player", "What's a TechPass?")
    pdf.dialogue_line("Sergey", "Hah. You must have hit head very hard. Everyone has TechPass.")
    pdf.dialogue_line("Narrator", "He holds up a card.", "narrator")
    pdf.dialogue_line("Sergey", "It is... how to say... your key to the world. Without it, you cannot use public tech. No terminals, no dispensers, no doors that scan ID. So now we use TechPass. Small card, but big headache. Lose it, and suddenly you are nobody.")
    pdf.dialogue_line("Sergey", "Machine will not work for you unless you put your TechPass inside. MemoryBox is very strict with the permissions. You really do not remember having one? ...That is not good.")
    pdf.dialogue_line("Player", "Could I... borrow yours? Just for a moment?")
    pdf.dialogue_line("Sergey", "Borrow? Moya devushka, this is not phone charger. If someone else uses my Techpass, system records it against my name. It is... risky. I'm sorry. I cannot do that.")
    pdf.dialogue_line("Sergey", "But... I can help you make application to HAVEMORE. If I add my name, maybe they look at it sooner. They know me there.")
    pdf.ln(2)

    pdf.section_header("The Manipulation (Player's Internal Monologue)", 4)
    pdf.dialogue_line("Narrator", "He wants to help. And though you barely know him, you can tell he's a kind man. He checks all the boxes.", "narrator")
    pdf.dialogue_line("Player", "Soft voice. Kind eyes. That gentle, almost apologetic way he carries himself. You've known his type before. And while you may not remember much of your past - you remember one thing. You've made kind men and women like him bend before. All you need to do is push a few buttons in the right order. You know where to start...", "internal")
    pdf.ln(2)

    pdf.section_header("Exploiting His Loneliness", 4)
    pdf.dialogue_line("Player", "You must get tired of being alone here.")
    pdf.dialogue_line("Sergey", "Tired? Da. Hospital is loud... but still feels empty. Days blend together. Nurse Bot comes, Nurse Bot goes. Only 'friend' is that Old Man on the other corner. Sad though, he do not speak much. So yes. Alone is good word.")
    pdf.dialogue_line("Player", "It must be hard. No family visiting?")
    pdf.dialogue_line("Sergey", "Family is... complication. Children live far. We do not speak much these days. Wife... she passed long time ago.")
    pdf.dialogue_line("Sergey", "This is punishment, I suppose. I was difficult man in my younger years. Never home. So now... I sit here. And my children somewhere else.")
    pdf.dialogue_line("Narrator", "You can tell he's hungry to be seen. Naturally. It's the one thing everyone needs to some extent in their life.", "narrator")
    pdf.ln(2)

    pdf.section_header("The Seduction & Intimate Scene", 4)
    pdf.dialogue_line("Narrator", "You step closer to this gentle giant. You place your hands on the mattress and hoist yourself up, settling casually on the edge of his bed.", "narrator")
    pdf.dialogue_line("Sergey", "Devushka... are you okay? Why are you looking like that?")
    pdf.dialogue_line("Narrator", "You slide even closer to him. He starts blushing. You're half his size. Yet, he looks at you like a schoolboy who's just realized his teacher knows exactly what he's thinking.", "narrator")
    pdf.dialogue_line("Player", "This feels... familiarly powerful?", "internal")
    pdf.ln(2)

    pdf.dialogue_line("", "Player advances on Sergey, who nervously deflects but cannot bring himself to resist.", "action")
    pdf.dialogue_line("", "Player places her hand on Sergey's thigh. He stiffens but doesn't push her away.", "action")
    pdf.dialogue_line("Sergey", "Devushka... please. This is... we are in hospital. You are confused. Must be medication.")
    pdf.dialogue_line("Player", "I'm not confused, Sergey. Trust me. And I know exactly who I'm touching.")
    pdf.dialogue_line("Player", "Listen Sergey, you ever wake up really horny? I usually do. And given how long I had been sleeping... I'm EXTRA horny. Won't you help a girl out? I need you.")
    pdf.dialogue_line("Sergey", "You need... me? Boze moy...")
    pdf.ln(2)

    pdf.section_header("McBucket Interruption", 4)
    pdf.italic_text("If McBucket has NOT been drugged with Zanopram:")
    pdf.dialogue_line("Old Man", "REEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE~~~~~~~~")
    pdf.dialogue_line("Narrator", "The patient across the room screams, shattering the moment. Both you and Sergey flinch and pull back.", "narrator")
    pdf.dialogue_line("Player", "I'm sorry, I got carried away.")
    pdf.dialogue_line("Sergey", "No, it is okay. Don't apologize. Sergey got carried away too. This Old Man has lost it. Can't do nothing in front of him.")
    pdf.dialogue_line("Player", "But, I still want to continue!")
    pdf.dialogue_line("Sergey", "I... I do too. It is just... this guy. I cannot do anything in front of him. If only there was anything that could calm him down for a little while...")
    pdf.dialogue_line("Player", "Don't worry, I will take care of it.")
    pdf.dialogue_line("Player", "'And I would really like your TechPass, sweetheart' is what you want to say. 'Me too! Sergey.' is what you end up saying instead. Okay then, comatose girl. Let's get this bread.", "internal")
    pdf.italic_text("The player must now drug McBucket with Zanopram to put him to sleep.")
    pdf.ln(3)

    pdf.section_header("Resuming After McBucket is Drugged", 4)
    pdf.dialogue_line("Narrator", "Having put the Old Man to sleep, you return to Sergey. He has retreated back into his shell during your absence. The blanket is pulled up tight, hiding his legs again.", "narrator")
    pdf.dialogue_line("Player", "Let's make this quick. I need to get the fuck out of here. And this gentle giant here holds the key. No worries, I got this.", "internal")
    pdf.dialogue_line("Player", "Missed me?")
    pdf.dialogue_line("Sergey", "Ah... You are back. It is... very quiet now. What did you do to him?")
    pdf.dialogue_line("Player", "I just helped him get some peace. Don't worry about him now, look at me.")
    pdf.dialogue_line("Sergey", "You know, I was half afraid you might not return. That you would leave old Sergey... hanging.")
    pdf.dialogue_line("Player", "Aw, how CUTE. Lil' Sergey isn't afraid of what I did to the Old Man. He was afraid I wouldn't come back to finish the job. Well then, the quest is nearly complete. Time to get ready for the loot.", "internal")
    pdf.dialogue_line("Narrator", "You pull yourself closer to him. This time, you don't ask him for permission.", "narrator")
    pdf.dialogue_line("", "Player shuts Sergey up by placing a finger on his lips.", "action")
    pdf.dialogue_line("Player", "Mama's here.", "internal")
    pdf.ln(2)

    pdf.dialogue_line("", "Player reclines Sergey's hospital bed using the haptic strip on the bed frame.", "action")
    pdf.dialogue_line("", "Player and Sergey engage in an intimate encounter. The scene is suggestive - Player takes the lead throughout while Sergey remains passive and overwhelmed.", "action")
    pdf.dialogue_line("", "The intimate encounter reaches its conclusion. Both characters take a moment to compose themselves.", "action")
    pdf.ln(2)

    pdf.dialogue_line("Narrator", "For a moment, the room falls silent. You take a moment to fix your gown. Sergey tries to compose himself.", "narrator")
    pdf.dialogue_line("Sergey", "Devushka... I don't know what to say.")
    pdf.dialogue_line("Player", "You don't need to say anything, Sergey.")
    pdf.dialogue_line("Narrator", "You reach up to his forehead. There is a long strand of your hair sticking to his sweat-dampened skin. You pinch it and peel it off him, slowly.", "narrator")
    pdf.dialogue_line("Player", "Oops! Sorry about that.")
    pdf.dialogue_line("Sergey", "T-Thanks, Devushka.")
    pdf.dialogue_line("Player", "That's it. He's primed. All you gotta do now is let him soak in the silence. 3... 2.. 1.", "internal")
    pdf.ln(2)

    pdf.section_header("Sergey Offers the TechPass", 4)
    pdf.dialogue_line("Sergey", "Devushka... so you wanted to use the MemoryBox, right? Now that I think... the process to get new pass might be too long. HAVEMORE bureaucracy is nightmare. Your bill will increase a lot if you wait. You can use mine if you want. Just for a while. If HAVEMORE raises a query, I hope they will let me off easy. I gave them twenty years of my life, after all!")
    pdf.dialogue_line("Player", "Bam. Wham. Thank you, Ma'am.", "internal")
    pdf.ln(2)
    pdf.italic_text("The player fake-refuses to avoid seeming manipulative:")
    pdf.dialogue_line("Player", "Sergey... thank you. But I cannot take this. I do not want you to feel pressured into giving me anything just because of what we just did. It feels... unethical.")
    pdf.dialogue_line("Sergey", "Unethical? No! No, please. Do not think like that. This is not... payment. This is... gift. From friend to friend. Please. I insist. If you do not take it, I will feel... bad. Like I took advantage of you.")
    pdf.dialogue_line("Player", "Well... if you put it that way. Thank you, Sergey.")
    pdf.dialogue_line("", "Item Acquired: TechPass", "system")
    pdf.dialogue_line("Player", "Stay put Sergey, let me figure out who I am and come see you again?")
    pdf.dialogue_line("Sergey", "Of course Devushka, I've got no where to go.")
    pdf.dialogue_line("Narrator", "Well, guess it's time to finally get to it, huh?", "narrator")

    # 1.7 Memory Box & Insurance Form
    pdf.add_page()
    pdf.section_header("1.7 Memory Box & Insurance Form", 2)
    pdf.italic_text("Source: generic_lines.dialogue, form_related_dialogue.dialogue")
    pdf.ln(3)

    pdf.section_header("MemoryBox - Locked (no TechPass)", 3)
    pdf.dialogue_line("Player", "Hmmm. The screen says I need to insert my TechPass to begin.", "internal")
    pdf.italic_text("Contextual lines based on who told the player about the TechPass:")
    pdf.body_text('- If both AIda and Sergey mentioned it: "This must be the card the Nurse and Sergey were talking about."')
    pdf.body_text('- If only AIda: "This must be the card the Nurse mentioned."')
    pdf.body_text('- If only Sergey: "This must be the card Sergey was talking about."')
    pdf.body_text('- If neither: "Fuck is that, now?"')
    pdf.ln(2)

    pdf.section_header("MemoryBox - Unlocked (has TechPass)", 3)
    pdf.dialogue_line("Narrator", "You slide the TechPass into the card slot.", "narrator")
    pdf.dialogue_line("Memory Box", "Please place the headset on.")
    pdf.dialogue_line("Narrator", "You pick up the strange device and place it over your head.", "narrator")
    pdf.dialogue_line("Player", "Alright... here goes. If this thing works... I might finally remember who I am.", "internal")
    pdf.ln(2)

    pdf.section_header("Insurance Form", 3)
    pdf.dialogue_line("Player", 'Fi...ona? Fiona! That\'s it! That\'s my name! I remember!')
    pdf.italic_text("On incorrect first name entry:")
    pdf.dialogue_line("Player", "{{wrong_name}}? What a trash name. Surely I wasn't named that!")
    pdf.italic_text("On field not ready:")
    pdf.dialogue_line("Player", "I don't think I've come across information that will help me in filling up this field yet. Maybe after I've sorted my memories out using the memory box, I'll be able to do this.", "internal")

    # 1.8 Dev CTA
    pdf.add_page()
    pdf.section_header("1.8 Dev CTA / End of Demo", 2)
    pdf.italic_text("Source: dev_cta.dialogue")
    pdf.italic_text("A fourth-wall-breaking scene that plays when the player tries to access a locked level.")
    pdf.ln(3)

    pdf.dialogue_line("Player", "I clicked on the locked level. And then, I couldn't believe what I saw. What I saw was the weirdest... The creepiest... The scariest...")
    pdf.dialogue_line("Lewgend", "DEV INSERT! Hey! I'm Lewgend. How are ya? Well, I've got news. Good and bad. So... bad news first. The demo ends here. Yeah. I know. Bummer. But, good news? Your boy is COOKING. COOKING so much! I've so much planned for this game!")
    pdf.dialogue_line("Lewgend", "For example: Lemme call our first female love interest... Layla! Layla! Get over here would ya?")
    pdf.dialogue_line("Layla", "HEY Lew! Called me? What's up? How's it going?")
    pdf.dialogue_line("Lewgend", "Hey! All good, Layla! You seem upbeat today.")
    pdf.dialogue_line("Layla", "Oh, well, you know, just trying to keep my spirits up. Kinda hard, though... you know? Since you decided to give your protagonist bigger titties than me!")
    pdf.dialogue_line("Lewgend", "...Layla. Do we really need to do this right now? We're creating a body-positive game! Everybody is built differently, you know?")
    pdf.dialogue_line("Layla", "Whatever. I hope you compensate for this atrocity by giving me a damn good character arc.")
    pdf.dialogue_line("Lewgend", "Oh, you bet! Creating a rich world with interesting characters is the primary goal of this game!")
    pdf.italic_text("Layla exits.")
    pdf.ln(2)
    pdf.dialogue_line("Lewgend", "Hah. Classic Layla. She really is something. But hey! Let's not forget about our first male love interest... Malcolm! Malcolm, get in here my man.")
    pdf.dialogue_line("Malcolm", "You sure about that? Last time we discussed this, you said I wasn't ready to be shown.")
    pdf.italic_text("Awkward pause. Lewgend tackles Malcolm off-screen.")
    pdf.dialogue_line("Malcolm", "Nooooooooooooooo!")
    pdf.dialogue_line("Lewgend", "I forgot I was using a template sprite for him. Hehe. But worry not! We plan on having multiple polished love interests in the game!")
    pdf.ln(2)
    pdf.dialogue_line("Lewgend", "Making this game has been really fun! It's taught me so much. But if I am to continue making this game... I'll need your support. I want to form a team! With artists, sound designers, programmers, and animators! But as it stands, I'm too broke to do that right now. Hehe.")
    pdf.dialogue_line("Lewgend", "So, it would mean the world to me if you could lend me your support!")
    pdf.dialogue_line("", "Patreon button appears", "action")
    pdf.dialogue_line("Lewgend", "The best way to support would be to join my Patreon as a paying subscriber! Patrons get the newest version of the game AS SOON as it's ready! No waiting around! Plus sneak peeks, development updates, and other fun lil' goodies along the way.")
    pdf.dialogue_line("Lewgend", "And hey... if money happens to be a bit tight right now? I get it. We've all been there. You can still join the Patreon as a free member! It genuinely helps out a ton, too.")
    pdf.dialogue_line("Lewgend", "Anyway, that's all I had to say. If you liked the demo, you'll definitely be seeing more of me! I'm hoping to release the next major update within the next three months. Well... no promises, though. Hehe. Truly, thank you for taking the time to play my game! Toodles!")

    # ============================================================
    # PART 2: INTERACTION DIALOGUE
    # ============================================================
    pdf.add_page()
    pdf.section_header("PART 2: INTERACTION DIALOGUE", 1)
    pdf.body_text("This section covers all dialogue triggered by the verb-based interaction system. The player selects a verb (examine, talk to, pick up, use, give, flash) and clicks on an object.")

    # 2.1 EXAMINE
    pdf.section_header("2.1 Examine Responses", 2)
    pdf.italic_text("Source: examinables.dialogue")
    pdf.ln(2)

    examine_items = [
        ("Default", '"Huh, I don\'t know what to make of this object."'),
        ("Burger", '"A burger, this is."'),
        ("Rusty Key", '"Goddamn rusty ass key ugh."'),
        ("AIda", '"A woman, in a nurse\'s attire. Her limbs seem to be metallic though? And damn, why she kinda..."'),
        ("Invigirol", '"A medicine container. Eighteen months from expiry. Label provides no description."'),
        ("Cannathink", '"A medicine container. 6 months from expiry. Label provides no description."'),
        ("Zanopram", '"A medicine container. 11 months from expiry. Label provides no description."'),
        ("Medicine Cabinet", '"A cabinet of sorts. Seems like it\'s got an assortment of capsule-shaped drugs inside. Tee-hee."'),
        ("McBucket (default)", '"An Old Man hooked up to a machine. You see not a single thought behind those googly eyes of his."'),
        ("McBucket (cannathink)", '"The old man stares blankly into space. Damn, seems like the cannathink got him to calm down."'),
        ("McBucket (zanopram)", '"Zzzzzzz..." / "Out like a log. He\'s not getting in my way now."'),
        ("McBucket (invigirol)", '"Damn, the geezer is huffin\' an\' puffin\'. Can\'t be good."'),
        ("Sergey", '"A hunk of a man sits calmly on his bed. He has kind eyes, but I sense a certain sadness in him."'),
        ("McBucket's Dispenser", '"Some sort of medical care device. There is a capsule-shaped slot. The Old Man is hooked up to it."'),
        ("Memory Box (after AIda)", '"A console-like device. Must be the MemoryBox that metallic nurse was talking about."'),
        ("Memory Box (before AIda)", '"A console-like device. Reminds me of an hourglass."'),
        ("TV (first examine, on)", 'News interview plays. CEO Voss: "We don\'t run the country. We simply maintain it. The country runs through us."'),
        ("TV (on, repeat)", '"The interview with the CEO is still ongoing. I really don\'t like the smug look of this prick."'),
        ("TV (off)", '"A sleek wall-mounted TV that\'s turned off. The room is quieter, but I like that better."'),
        ("Toilet Paper Dispenser", '"An automatic toilet paper dispenser. The paper seems to be quite thick. Must be of premium quality."'),
        ("Bathroom Mirror", '"Wow, now this is a fancy mirror. Seems to be displaying the date and time on the top right."'),
        ("Hospital Toilet (default)", '"This is where I could take a dump, if I needed to... Wait, the water level\'s kinda... low?"'),
        ("Hospital Toilet (has paper)", '"The dropped toilet paper has clumped together into a soggy ball. Probably won\'t flush well..."'),
        ("Hospital Toilet (clogged)", '"I\'ve successfully clogged this dumper. What now, though?"'),
    ]

    pdf.table_row("Object", "Player's Response", header=True)
    for obj, resp in examine_items:
        pdf.table_row(obj, resp)

    # 2.2 TALK TO
    pdf.add_page()
    pdf.section_header("2.2 Talk To Responses", 2)
    pdf.italic_text("Source: talkto.dialogue, untalkables.dialogue")
    pdf.ln(2)

    talk_items = [
        ("Default (inanimate)", '"I don\'t think that\'s going to talk back to me."'),
        ("Burger", '"talk to a burger, I can\'t"'),
        ("Soup", '"hello soup! you\'re not feeling very talkative today are you?"'),
        ("Rusty Key", '"Hello, er...key?"'),
        ("Medicine Cabinet", '"Hello sir. I heard you have drugs in you. Sigh... What am I doing."'),
        ("Bathroom Mirror", '"Mirror, mirror... on the wall. Who\'s the sexiest comatose patient of \'em all?"'),
        ("TV", '"Huh... I\'m not sure how the voice control on this works."'),
        ("Any Door", '"Open Sesame! ... Well, that didn\'t work."'),
    ]

    pdf.table_row("Object", "Player's Response", header=True)
    for obj, resp in talk_items:
        pdf.table_row(obj, resp)

    # 2.3 PICK UP
    pdf.ln(4)
    pdf.section_header("2.3 Pick Up Responses", 2)
    pdf.italic_text("Source: unpickables.dialogue")
    pdf.ln(2)

    pickup_items = [
        ("Default", '"I can\'t pick that up."'),
        ("AIda", '"Pick her up? Heh. I wish..."'),
        ("Sergey", '"He\'s a bit too heavy for me..."'),
        ("McBucket", '"I bet I could pick him up if I tried. But... why would I?"'),
        ("Medicine Cabinet", '"I can\'t pick this up. The drugs that are inside though. Different story."'),
        ("McBucket's Dispenser", '"Can\'t pick this up. Might be able to use or give something here, though."'),
        ("Memory Box", '"Can\'t pick this up. Might be able to use something on it though. Something like a... card?"'),
        ("TV", '"Sigh... I want to pick the TV? Seriously?"'),
        ("Any Door", '"Sure, let\'s pick the damn door. Genius..."'),
        ("Bathroom Mirror", '"Seriously? Pick up a bathroom mirror bolted to the wall? What am I, stupid?"'),
    ]

    pdf.table_row("Object", "Player's Response", header=True)
    for obj, resp in pickup_items:
        pdf.table_row(obj, resp)

    # 2.4 USE
    pdf.add_page()
    pdf.section_header("2.4 Use Responses", 2)
    pdf.italic_text("Source: unusables.dialogue")
    pdf.ln(2)

    use_items = [
        ("Default", '"That doesn\'t seem to work."'),
        ("Exit Door", 'Speaker: "Please fill in your insurance details before attempting to leave."'),
        ("Sergey", '"Use? This hunk of a man? Hmmmmm."'),
        ("Toilet (no need)", '"I don\'t really need to go right now. Besides, isn\'t the water level kinda... low?"'),
        ("Toilet (paper dropped)", '"I\'ve already dropped quite a bit of that in already."'),
        ("Toilet (clogged)", '"This is already broken. Adding more buttpaper would be futile."'),
        ("Bathroom Mirror", '"Damn... my mug ain\'t half bad, huh?"'),
        ("McBucket (plain use)", '"He might actually be useless, I\'m afraid."'),
        ("TV (toggle off)", '"I\'ll just hit this switch here..." [TV turns off]'),
        ("TV (toggle on)", '"Let\'s turn that back on." / "Ah, this soothing static."'),
        ("Drug on AIda", '"I don\'t see a slot to insert a medicine cartridge in her..."'),
        ("Drug on wrong person", '"I don\'t think I can just shove these cartridges down someone\'s throat."'),
        ("TP on McBucket", '"While shoving toilet paper down one\'s throat is a valid strategy..."'),
        ("Wipe object with TP", '"Well... I still feel empty inside." [TP consumed]'),
        ("Drug on TV/Cabinet", '"There is no universe in which this makes sense."'),
        ("TechPass on wrong machine", '"I might be using this on the wrong machine..."'),
        ("Toilet + drug", '"This really isn\'t my brightest idea, is it?"'),
        ("Toilet + TechPass", '"Sure! Let me just flush all my hard work down the shitter!"'),
    ]

    pdf.table_row("Object/Combo", "Player's Response", header=True)
    for obj, resp in use_items:
        pdf.table_row(obj, resp)

    # 2.5 GIVE
    pdf.add_page()
    pdf.section_header("2.5 Give Responses", 2)
    pdf.italic_text("Source: giveables.dialogue")
    pdf.ln(2)

    give_items = [
        ("Default", '"I don\'t think they want that."'),
        ("AIda + Toilet Paper", 'AIda: "Thanks!" [Item removed]'),
        ("Sergey + TechPass", 'Sergey: "Devushka, I don\'t think you want to give this back just yet."'),
        ("Sergey + Toilet Paper", 'Sergey: "Oh. Toilet paper. Ummm... Thanks?" / "Maybe this wasn\'t the most thoughtful gift."'),
        ("AIda + any drug", '"Sure, lemme just hand her the drugs I stole from under her nose."'),
        ("AIda + TechPass", '"I think she might confiscate this from me if I show it to her..."'),
        ("McBucket + TechPass", '"Why would I want him to have that?"'),
        ("McBucket (awake)", 'McBucket: "Ree~!"'),
        ("McBucket (sleeping)", '"He seems to be out like a log. Can\'t give him nothing."'),
        ("Empty inventory", '"I don\'t have anything on me to give."'),
        ("No item selected", '"I should probably figure out what I want to give them first."'),
    ]

    pdf.table_row("Recipient + Item", "Response", header=True)
    for obj, resp in give_items:
        pdf.table_row(obj, resp)

    # 2.6 FLASH
    pdf.ln(4)
    pdf.section_header("2.6 Flash Responses", 2)
    pdf.italic_text("Source: flash_dialogue.dialogue, unflashables.dialogue")
    pdf.italic_text('The "Flash" verb allows the player to expose herself to NPCs.')
    pdf.ln(2)

    flash_items = [
        ("Default (objects)", '"There\'s no reason to shine my light on that."'),
        ("Self", '"Ah! My eyes! Why did I do that?"'),
        ("AIda (not spoken yet)", '"I think it\'ll be better to try talking to her first." [Aborted]'),
        ("AIda (post-flash)", 'AIda: "Your mammary tissue health appears statistically outstanding! Would you like a clinical breast examination?"'),
        ("McBucket (on cannathink)", 'Old Man: "Aphrodite? Ye almighty Aphrodite? Ye bless me with yer presence?"'),
        ("McBucket (default)", '"Wait... Something\'s happening to him." [Enters hyper/invigirol state]'),
        ("McBucket (sleeping)", '"Dangling a carrot in front of a sleeping rabbit like that."'),
        ("Sergey (no TechPass)", '"I don\'t think it will be a good idea to flash him just yet." [Aborted]'),
        ("Sergey (post-flash)", '"Sergey smiles shyly." / "Got \'em."'),
    ]

    pdf.table_row("Target", "Response", header=True)
    for obj, resp in flash_items:
        pdf.table_row(obj, resp)

    # ============================================================
    # PART 3: ENVIRONMENTAL & PUZZLE
    # ============================================================
    pdf.add_page()
    pdf.section_header("PART 3: ENVIRONMENTAL & PUZZLE DIALOGUE", 1)

    # 3.1 Toilet Puzzle
    pdf.section_header("3.1 Toilet Puzzle Chain", 2)
    pdf.italic_text("Source: use_item_accompanying_dialogue.dialogue, aida_toilet_assistance.dialogue")
    pdf.italic_text("The toilet puzzle is the game's primary puzzle chain: clog toilet -> AIda investigates -> steal medicine -> drug McBucket.")
    pdf.ln(3)

    pdf.section_header("Step 1: Discover the weak flush", 4)
    pdf.dialogue_line("Narrator", "You push the flush button.", "narrator")
    pdf.dialogue_line("Narrator", "Hmm. It seems to be rather weak. Maybe maintenance is due.", "narrator")
    pdf.ln(2)

    pdf.section_header("Step 2: Drop toilet paper", 4)
    pdf.dialogue_line("Narrator", "You dropped the thick toilet paper into the toilet.", "narrator")
    pdf.ln(2)

    pdf.section_header("Step 3: Flush clogged toilet", 4)
    pdf.dialogue_line("Toilet", "Warning. Obstruction detected. Water flow below acceptable levels. Maintenance assistance requested.")
    pdf.dialogue_line("Player", "...Woah. What the fuck is this place?")
    pdf.ln(2)

    pdf.section_header("Step 4: AIda responds to alert", 4)
    pdf.dialogue_line("AIda", "Hey Patient #122! It seems like you blocked the toilet - I received a maintenance alert! Gastro activity of this magnitude is a great sign during this phase of your recovery. Most patients are unable to do that!")
    pdf.dialogue_line("Player", "Ah, amazing. The Robo-Nurse thinks I just took a big boy shit. Anyway... what was I gonna do?", "internal")
    pdf.ln(2)

    pdf.section_header("Step 5: Steal from medicine cabinet", 4)
    pdf.dialogue_line("Player", "The nurse isn't looking over here right now. I'll just slip this in here real quick...", "internal")
    pdf.ln(2)

    pdf.section_header("If AIda catches player at cabinet:", 4)
    pdf.dialogue_line("AIda", "Hey patient #122, that cabinet is reserved for clinical staff. If you are experiencing discomfort, I can assist with approved medication.")
    pdf.dialogue_line("Player", "Huh. Looks like I can't open the medicine cabinet while she's still around.", "internal")
    pdf.ln(2)

    pdf.section_header("Step 6: Drug McBucket's dispenser", 4)
    pdf.dialogue_line("Player", "The nurse isn't looking over here right now. I'll just slip this in here real quick...", "internal")

    # 3.2 Progression Gates
    pdf.add_page()
    pdf.section_header("3.2 Progression Gates", 2)
    pdf.italic_text("Source: generic_lines.dialogue")
    pdf.ln(2)

    gate_items = [
        ("Talk to NPC before AIda", '"I think I should talk to the Nurse before I talk to anyone else."'),
        ("Talk to NPC before MemoryBox", '"The Nurse told me to use the memory box. Better do that first."'),
        ("Touch MemoryBox before AIda", '"I should probably talk to the nurse before I touch this weird machine."'),
        ("McBucket sleeping (talk)", '"The old man seems to be out cold right now."'),
        ("Give med to sleeping McBucket", '"The Old Man seems unaffected. His sleep is deep."'),
        ("Return to Sergey before drugging", '"The Old Man still seems to be up. I better take care of him before returning to Sergey."'),
    ]

    pdf.table_row("Trigger", "Player's Response", header=True)
    for trigger, resp in gate_items:
        pdf.table_row(trigger, resp)

    # 3.3 Hint System
    pdf.ln(4)
    pdf.section_header("3.3 Hint System", 2)
    pdf.italic_text("Source: hints_adventure.dialogue")
    pdf.italic_text("The game provides contextual hints based on the player's current progress.")
    pdf.ln(2)

    hint_items = [
        ("Start", '"Where... where am I? Is this a hospital? I should probably talk to that Nurse."'),
        ("After AIda", '"The Nurse told me to use the MemoryBox. It must be that weird, hourglass-like device."'),
        ("After trying MemoryBox", '"This machine requires a TechPass. Wonder where I can find one around here..."'),
        ("Need to drug McBucket", '"The Old Man is a nuisance. I need to find a way to shut him up."'),
        ("Wrong drugs used", '"They haven\'t put him to sleep yet. I should use Zzzanopram."'),
        ("McBucket asleep", '"The Old Man\'s asleep. Time to return to Sergey."'),
        ("Has TechPass", '"I have the TechPass. All I need to do now is use it on that weird machine."'),
    ]

    pdf.table_row("Game State", "Hint", header=True)
    for state, hint in hint_items:
        pdf.table_row(state, hint)

    # ============================================================
    # APPENDIX
    # ============================================================
    pdf.add_page()
    pdf.section_header("APPENDIX", 1)

    pdf.section_header("A. Critical Path Walkthrough", 2)
    steps = [
        "1. WAKE UP - Survive the intro by choosing to keep pushing through the darkness.",
        "2. TALK TO AIDA - Learn about your situation, get the Neural Integrity Scan, receive the insurance form tablet.",
        "3. TRY THE MEMORYBOX - Discover it's locked and requires a TechPass.",
        "4. REPORT BACK TO AIDA - Learn TechPass replacement takes 30 days. Unacceptable.",
        "5. TALK TO SERGEY - Learn about TechPass, ask to borrow his, get refused.",
        "6. SEDUCE SERGEY - Exploit his loneliness. Get interrupted by McBucket screaming.",
        "7. GO TO BATHROOM - Pick up thick toilet paper from the dispenser.",
        "8. CLOG THE TOILET - Drop toilet paper in toilet, flush to clog it.",
        "9. WAIT FOR AIDA - She receives the maintenance alert and goes to investigate.",
        "10. STEAL MEDICINE - While AIda is away, open the medicine cabinet. Take Zanopram.",
        "11. DRUG MCBUCKET - Use Zanopram on McBucket's medicine dispenser. He falls asleep.",
        "12. RETURN TO SERGEY - Resume the intimate encounter without interruption.",
        "13. OBTAIN TECHPASS - After the encounter, Sergey voluntarily offers his TechPass.",
        "14. USE MEMORYBOX - Insert TechPass, put on headset, begin memory recovery.",
        "15. FILL INSURANCE FORM - Enter recovered details (name: Fiona).",
        "16. EXIT - Use the exit door (requires completed insurance form).",
    ]
    for step in steps:
        pdf.set_font("Helvetica", "", 10)
        pdf.set_text_color(50, 50, 50)
        pdf.cell(5)
        pdf.multi_cell(0, 6, step)
        pdf.ln(1)

    pdf.ln(4)
    pdf.section_header("B. Miscellaneous & Debug Files", 2)
    pdf.body_text("The following files exist in the project but are not part of normal gameplay:")
    misc_items = [
        "testdialogue.dialogue - Tests the cinematic system with AIda playing a tape.",
        "IfElseTest.dialogue - Tests dialogue_manager's simultaneous line feature.",
        "mcbucket_thinking_dialogue.dialogue - Placeholder for the 'think' verb.",
        "AIda_rough.dialogue - Earlier draft of AIda's intro conversation.",
        "sergey_dialogue_2.dialogue - Older standalone version of post-drugging Sergey scene.",
        "dialogue/npcs/faye.dialogue - Older version of the intro sequence.",
        "aida_dialogue_hub.dialogue - Contains only a placeholder line.",
        "player_examine_lines.dialogue - Empty file.",
    ]
    for item in misc_items:
        pdf.set_font("Helvetica", "", 9)
        pdf.set_text_color(80, 80, 80)
        pdf.cell(5)
        pdf.multi_cell(0, 5.5, f"- {item}")
        pdf.ln(1)

    pdf.ln(10)
    pdf.set_draw_color(150, 150, 150)
    pdf.line(60, pdf.get_y(), pdf.w - 60, pdf.get_y())
    pdf.ln(8)
    pdf.set_font("Helvetica", "I", 10)
    pdf.set_text_color(120, 120, 120)
    pdf.cell(0, 6, "End of Master Dialogue Document", align="C")
    pdf.ln(6)
    pdf.cell(0, 6, 'Game: "If I Remember Correctly" | Engine: Godot 4 (GDScript)', align="C")
    pdf.ln(6)
    pdf.cell(0, 6, "Dialogue System: dialogue_manager addon", align="C")

    output_path = r"C:\Godot\If I Remember Correctly\testgodot\IIRC_Master_Dialogue_Document.pdf"
    pdf.output(output_path)
    print(f"PDF generated: {output_path}")
    print(f"Total pages: {pdf.page_no()}")

if __name__ == "__main__":
    build_pdf()
