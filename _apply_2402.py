# Clean apply and verify script for Step 2.402

def apply_edits(filepath, edits, is_crlf=False):
	b = open(filepath, 'rb').read()
	c = b.decode('utf-8')
	if is_crlf:
		newline = '\r\n'
	else:
		newline = '\n'
	
	# Normalize to \n for replacement matching
	c_norm = c.replace('\r\n', '\n')
	
	for i, (f, r) in enumerate(edits):
		cnt = c_norm.count(f)
		assert cnt == 1, f"{filepath} Edit {i+1}: count was {cnt}"
		c_norm = c_norm.replace(f, r, 1)
	
	if is_crlf:
		out = c_norm.replace('\n', '\r\n')
	else:
		out = c_norm
	
	open(filepath, 'wb').write(out.encode('utf-8'))
	print(f"Successfully applied {len(edits)} edits to {filepath}!")

# Task 1
t1_edits = [
	("""Layla: Fionaaaa! You fell asleep while working again!""", """do actor_change("Fiona", "jacket")\nLayla: Fionaaaa! You fell asleep while working again!"""),
	("""Player: Also, what's this thing over me?""", """do actor_change("Fiona", "jacket_suspicious")\nPlayer: Also, what's this thing over me?"""),
	("""Player: Oh.""", """do actor_change("Fiona", "jacket")\nPlayer: Oh."""),
	("""Player: Thanks, Layla.""", """do actor_change("Fiona", "base")\nPlayer: Thanks, Layla."""),
	("""Player: You know that you could easily do it yourself though, right?""", """do actor_change("Fiona", "explain")\nPlayer: You know that you could easily do it yourself though, right?"""),
	("""Player: No worries. Let's get to the lab ASAP. I need to go home and shower after this.""", """do actor_change("Fiona", "base")\nPlayer: No worries. Let's get to the lab ASAP. I need to go home and shower after this."""),
	("""What do you want to say to her?""", """do actor_change("Fiona", "base")\nWhat do you want to say to her?"""),
	("""\t\tPlayer: Layla, wait outside, okay? I'll see if there's anything I can find in the office and come out.""", """\t\tdo actor_change("Fiona", "explain")\n\t\tPlayer: Layla, wait outside, okay? I'll see if there's anything I can find in the office and come out."""),
	("""\t\tPlayer: We need to find some dirt on that... dirtbag.""", """\t\tdo actor_change("Fiona", "suspicious")\n\t\tPlayer: We need to find some dirt on that... dirtbag."""),
	("""\t\tPlayer: Yes. But... where should we look?""", """\t\tdo actor_change("Fiona", "thinking")\n\t\tPlayer: Yes. But... where should we look?"""),
	("""\t\tPlayer: So, as I mentioned earlier...""", """\t\tdo actor_change("Fiona", "explain")\n\t\tPlayer: So, as I mentioned earlier..."""),
	("""\t\t\t\tPlayer: Don't worry. We've got this.""", """\t\t\t\tdo actor_change("Fiona", "base")\n\t\t\t\tPlayer: Don't worry. We've got this."""),
	("""\t\tPlayer: What we need to do now is find the precise date Julian mentioned.""", """\t\tdo actor_change("Fiona", "explain")\n\t\tPlayer: What we need to do now is find the precise date Julian mentioned."""),
	("""\t\tPlayer: Hmmm.""", """\t\tdo actor_change("Fiona", "thinking")\n\t\tPlayer: Hmmm."""),
	("""\t\tPlayer: So, it seems like the janitor can't help us much either...""", """\t\tdo actor_change("Fiona", "thinking")\n\t\tPlayer: So, it seems like the janitor can't help us much either..."""),
	("""\t\tPlayer: Probably.""", """\t\tdo actor_change("Fiona", "base")\n\t\tPlayer: Probably."""),
	("""\t\tPlayer: (But... who?)""", """\t\tdo actor_change("Fiona", "thinking")\n\t\tPlayer: (But... who?)"""),
	("""\tPlayer: Oh, don't worry, Layla. I've met thousands like him.""", """\tdo actor_change("Fiona", "shrug")\n\tPlayer: Oh, don't worry, Layla. I've met thousands like him."""),
	("""\tPlayer: You know, I'm happy to help you with this, but I have to ask...""", """\tdo actor_change("Fiona", "explain")\n\tPlayer: You know, I'm happy to help you with this, but I have to ask..."""),
	("""\t\tPlayer: That's... alright.""", """\t\tdo actor_change("Fiona", "hands_back")\n\t\tPlayer: That's... alright."""),
	("""\t\tPlayer: Afraid?""", """\t\tdo actor_change("Fiona", "suspicious")\n\t\tPlayer: Afraid?"""),
	("""\t\tPlayer: Careful doesn't get results.""", """\t\tdo actor_change("Fiona", "explain_suspicious")\n\t\tPlayer: Careful doesn't get results."""),
	("""\t\tPlayer: Good.""", """\t\tdo actor_change("Fiona", "base")\n\t\tPlayer: Good."""),
	("""\tPlayer: So... apart from work, what've you been up to lately?""", """\tdo actor_change("Fiona", "hands_back")\n\tPlayer: So... apart from work, what've you been up to lately?"""),
	("""\t\tPlayer: What? No.""", """\t\tdo actor_change("Fiona", "shy")\n\t\tPlayer: What? No."""),
	("""\tPlayer: I'm okay, actually.""", """\tdo actor_change("Fiona", "hands_back")\n\tPlayer: I'm okay, actually."""),
	("""\tPlayer: I didn't realize you liked fashion that much.""", """\tdo actor_change("Fiona", "base")\n\tPlayer: I didn't realize you liked fashion that much."""),
	("""\t\tPlayer: Oh. Do you mind if I ask why?""", """\tdo actor_change("Fiona", "hands_back")\n\t\tPlayer: Oh. Do you mind if I ask why?"""),
	("""\t\tPlayer: I'm sorry about that. I hope you can find your confidence someday.""", """\tdo actor_change("Fiona", "hands_back_sad")\n\t\tPlayer: I'm sorry about that. I hope you can find your confidence someday."""),
	("""\t\tPlayer: For me, clothes are just a matter of convenience.""", """\tdo actor_change("Fiona", "shrug")\n\t\tPlayer: For me, clothes are just a matter of convenience."""),
	("""\t\tPlayer: Layla, you alright?""", """\tdo actor_change("Fiona", "suspicious")\n\t\tPlayer: Layla, you alright?"""),
	("""\t\tPlayer: Riiiight.""", """\tdo actor_change("Fiona", "suspicious")\n\t\tPlayer: Riiiight."""),
	("""\t\tPlayer: Riiiight.\n\t\tPlayer: Anyway...""", """\t\tPlayer: Riiiight.\n\t\tdo actor_change("Fiona", "base")\n\t\tPlayer: Anyway..."""),
	("""\t\tPlayer: That's... interesting.""", """\tdo actor_change("Fiona", "suspicious")\n\t\tPlayer: That's... interesting."""),
	("""\t\tdo actor_effect("Layla", "slump")\n\t\tPlayer: Anyway...""", """\t\tdo actor_effect("Layla", "slump")\n\t\tdo actor_change("Fiona", "base")\n\t\tPlayer: Anyway...""")
]
apply_edits('dialogue/layla_chapter_1.dialogue', t1_edits, is_crlf=False)

# Task 2
t2_edits = [
	("""Player: Easiest date for an American to remember, baby.""", """do actor_change("Fiona", "explain")\nPlayer: Easiest date for an American to remember, baby."""),
	("""Player: Umm. Layla...""", """do actor_change("Fiona", "suspicious")\nPlayer: Umm. Layla..."""),
	("""Player: I need you to calm down.""", """do actor_change("Fiona", "shrug")\nPlayer: I need you to calm down."""),
	("""Player: We can figure out a way to get in.""", """do actor_change("Fiona", "base")\nPlayer: We can figure out a way to get in."""),
	("""Player: Maybe we should talk to that janitor.""", """do actor_change("Fiona", "thinking")\nPlayer: Maybe we should talk to that janitor."""),
	("""\tPlayer: I suppose. But he's our only lead.""", """\tdo actor_change("Fiona", "base")\n\tPlayer: I suppose. But he's our only lead."""),
	("""\tPlayer: He probably has access to every room in this building.""", """\tdo actor_change("Fiona", "base")\n\tPlayer: He probably has access to every room in this building."""),
	("""Player: Hehe.""", """do actor_change("Fiona", "shy")\nPlayer: Hehe."""),
	("""Player: Crazy. I really didn't expect this to work.""", """do actor_change("Fiona", "shrug")\nPlayer: Crazy. I really didn't expect this to work."""),
	("""\t\tPlayer: What do you mean? Am I not cute otherwise?""", """\tdo actor_change("Fiona", "suspicious")\n\t\tPlayer: What do you mean? Am I not cute otherwise?"""),
	("""Player: Huh... why's the professor calling me?""", """do actor_change("Fiona", "suspicious")\nPlayer: Huh... why's the professor calling me?"""),
	("""Player: Ummm... hello, Professor.""", """do actor_change("Fiona", "base")\nPlayer: Ummm... hello, Professor."""),
	("""Player: Oh no. I'm so sorry.""", """do actor_change("Fiona", "sad")\nPlayer: Oh no. I'm so sorry."""),
	("""Player: Yeah, well. So that happened.""", """do actor_change("Fiona", "hands_back_sad")\nPlayer: Yeah, well. So that happened."""),
	("""Player: What?""", """do actor_change("Fiona", "suspicious")\nPlayer: What?"""),
	("""Player: Heh. I agree.""", """do actor_change("Fiona", "base")\nPlayer: Heh. I agree."""),
	("""Player: I'm not sure...""", """do actor_change("Fiona", "shrug")\nPlayer: I'm not sure..."""),
	("""Player: Anyway, let's go in?""", """do actor_change("Fiona", "base")\nPlayer: Anyway, let's go in?""")
]
apply_edits('dialogue/keypad_lab.dialogue', t2_edits, is_crlf=False)

# Task 3
t3_edits = [
	("""Player: You know, I don't know why...""", """do actor_change("Fiona", "thinking")\nPlayer: You know, I don't know why..."""),
	("""Player: We should probably look in his office. Cut to the chase.""", """do actor_change("Fiona", "explain")\nPlayer: We should probably look in his office. Cut to the chase."""),
	("""Player: Huh. Seems like this... isn't it.""", """do actor_change("Fiona", "suspicious")\nPlayer: Huh. Seems like this... isn't it."""),
	("""\tPlayer: I was so certain it would be this. I verified it through the book in the library.""", """\tdo actor_change("Fiona", "sad")\n\tPlayer: I was so certain it would be this. I verified it through the book in the library."""),
	("""Player: No. We have another way.""", """do actor_change("Fiona", "base")\nPlayer: No. We have another way."""),
	("""Player: We look for clues in his office?""", """do actor_change("Fiona", "explain")\nPlayer: We look for clues in his office?"""),
	("""Player: Maybe. But... if I remember correctly, there aren't any cameras on the faculty office floor.""", """do actor_change("Fiona", "explain")\nPlayer: Maybe. But... if I remember correctly, there aren't any cameras on the faculty office floor."""),
	("""Player: I'm kinda having fun trying to break in.""", """do actor_change("Fiona", "shy")\nPlayer: I'm kinda having fun trying to break in."""),
	("""Player: Fair. But honestly, there's no way they'll do anything to me.""", """do actor_change("Fiona", "shrug")\nPlayer: Fair. But honestly, there's no way they'll do anything to me."""),
	("""Player: Sometimes a girl's gotta do what she's gotta do, you know?""", """do actor_change("Fiona", "shy")\nPlayer: Sometimes a girl's gotta do what she's gotta do, you know?"""),
	("""Player: Let's go?""", """do actor_change("Fiona", "base")\nPlayer: Let's go?""")
]
apply_edits('dialogue/keypad_attempts.dialogue', t3_edits, is_crlf=False)

# Task 4
t4_edits = [
	("""# TODO art: fiona's flash pose, e.g. do actor_change("Fiona", "flash").""", """# step 2.402: fiona's flash pose (her rig's flash body)."""),
	("""What do you want to say to him?""", """do actor_change("Fiona", "base")\nWhat do you want to say to him?"""),
	("""Player: I'm Fiona, and this is Layla. We work here, in the genomics lab.""", """do actor_change("Fiona", "explain")\nPlayer: I'm Fiona, and this is Layla. We work here, in the genomics lab."""),
	("""Player: Fair enough.""", """do actor_change("Fiona", "base")\nPlayer: Fair enough."""),
	("""\tPlayer: Don't worry. People like him can be made useful.""", """\tdo actor_change("Fiona", "suspicious")\n\tPlayer: Don't worry. People like him can be made useful."""),
	("""Player: Sure.""", """do actor_change("Fiona", "base")\nPlayer: Sure."""),
	("""Player: Hey. As maintenance, you must have access to all the rooms in this building, right?""", """do actor_change("Fiona", "explain")\nPlayer: Hey. As maintenance, you must have access to all the rooms in this building, right?"""),
	("""\t\tPlayer: I mean, I don't know. But probably not?""", """\t\tdo actor_change("Fiona", "shrug")\n\t\tPlayer: I mean, I don't know. But probably not?"""),
	("""Player: There's gotta be something we can do still.""", """do actor_change("Fiona", "thinking")\nPlayer: There's gotta be something we can do still."""),
	("""Player: So hey, Jayce. Jayce it was, right?""", """do actor_change("Fiona", "explain")\nPlayer: So hey, Jayce. Jayce it was, right?"""),
	("""Player: I see...""", """do actor_change("Fiona", "thinking")\nPlayer: I see..."""),
	("""Player: Not sure. We'll have to look around. There might be clues here.""", """do actor_change("Fiona", "shrug")\nPlayer: Not sure. We'll have to look around. There might be clues here."""),
	("""\tPlayer: It's alright. Never mind, Jayce. We'll look around and see what we can do.""", """\tdo actor_change("Fiona", "base")\n\tPlayer: It's alright. Never mind, Jayce. We'll look around and see what we can do."""),
	("""\tPlayer: Anyway. We should look for clues. Stuff around the building. Anything that pertains to Professor Greene.""", """\tdo actor_change("Fiona", "explain")\n\tPlayer: Anyway. We should look for clues. Stuff around the building. Anything that pertains to Professor Greene."""),
	("""\tPlayer: I'm letting you know this, though. It's probably a long shot.""", """\tdo actor_change("Fiona", "shrug")\n\tPlayer: I'm letting you know this, though. It's probably a long shot."""),
	("""\t\tPlayer: I would rate our chances of success at approximately...""", """\tdo actor_change("Fiona", "explain")\n\t\tPlayer: I would rate our chances of success at approximately..."""),
	("""\t\tPlayer: (I pulled that outta my ass. She takes everything I say at face value.)""", """\tdo actor_change("Fiona", "shy")\n\t\tPlayer: (I pulled that outta my ass. She takes everything I say at face value.)"""),
	("""\tPlayer: Anyway, let's go.""", """\tdo actor_change("Fiona", "base")\n\tPlayer: Anyway, let's go."""),
	("""What do you want to ask him?""", """do actor_change("Fiona", "base")\nWhat do you want to ask him?"""),
	("""Player: Hmm. That's... comforting.""", """do actor_change("Fiona", "suspicious")\nPlayer: Hmm. That's... comforting."""),
	("""Player: If you were us, where would you start looking?""", """do actor_change("Fiona", "thinking")\nPlayer: If you were us, where would you start looking?"""),
	("""Player: Not really. It's just us who work in this lab.""", """do actor_change("Fiona", "base")\nPlayer: Not really. It's just us who work in this lab."""),
	("""\t\tPlayer: Ugh.""", """\tdo actor_change("Fiona", "suspicious")\n\t\tPlayer: Ugh."""),
	("""\t\tPlayer: Ding-ding-ding.""", """\tdo actor_change("Fiona", "shrug")\n\t\tPlayer: Ding-ding-ding."""),
	("""\t\tPlayer: Well, there's one guy from that department who's entered our lab multiple times to talk to Professor Greene.""", """\tdo actor_change("Fiona", "hands_back")\n\t\tPlayer: Well, there's one guy from that department who's entered our lab multiple times to talk to Professor Greene."""),
	("""\t\tPlayer: Even though I'd rather not.""", """\tdo actor_change("Fiona", "shy")\n\t\tPlayer: Even though I'd rather not."""),
	("""\tPlayer: This is a template line.\ndo actor_change("Jayce", "base")\nPlayer: Right. Thanks.""", """\tPlayer: This is a template line.\ndo actor_change("Jayce", "base")\ndo actor_change("Fiona", "base")\nPlayer: Right. Thanks."""),
	("""Player: Well, there's this one guy who works in the OTHER lab.""", """do actor_change("Fiona", "hands_back")\nPlayer: Well, there's this one guy who works in the OTHER lab."""),
	("""do actor_change("Jayce", "base")\nPlayer: Right. Thanks.""", """do actor_change("Jayce", "base")\ndo actor_change("Fiona", "base")\nPlayer: Right. Thanks."""),
	("""Player: Hey, Jayce. That keycard you mentioned earlier...""", """do actor_change("Fiona", "explain")\nPlayer: Hey, Jayce. That keycard you mentioned earlier..."""),
	("""Player: We... actually need to look into the professor's office.""", """do actor_change("Fiona", "hands_back")\nPlayer: We... actually need to look into the professor's office."""),
	("""Player: (Yep... only one way to get sleazebags like him to do anything.)""", """do actor_change("Fiona", "suspicious")\nPlayer: (Yep... only one way to get sleazebags like him to do anything.)"""),
	("""do actor_change("Jayce", "stunned")""", """do actor_change("Fiona", "flash")\ndo actor_change("Jayce", "stunned")"""),
	("""You pull your top back down.""", """do actor_change("Fiona", "base")\nYou pull your top back down."""),
	("""Player: You got something out of this.""", """do actor_change("Fiona", "explain")\nPlayer: You got something out of this."""),
	("""Player: (Huh... he's agreeable all of a sudden.)""", """do actor_change("Fiona", "suspicious")\nPlayer: (Huh... he's agreeable all of a sudden.)"""),
	("""\t\tdo actor_change("Layla", "downcast")\n\t\tPlayer: Yep. Sorry if that bothered you.""", """\t\tdo actor_change("Layla", "downcast")\n\t\tdo actor_change("Fiona", "shy")\n\t\tPlayer: Yep. Sorry if that bothered you."""),
	("""\t\tdo actor_change("Layla", "downcast")\n\t\tPlayer: Let's go, then?""", """\t\tdo actor_change("Layla", "downcast")\n\t\tdo actor_change("Fiona", "base")\n\t\tPlayer: Let's go, then?"""),
	("""\t\tLayla: Fiona! You really just... did that!\n\t\tPlayer: Yep. Sorry if that bothered you.""", """\t\tLayla: Fiona! You really just... did that!\n\t\tdo actor_change("Fiona", "shy")\n\t\tPlayer: Yep. Sorry if that bothered you."""),
	("""\t\tdo actor_change("Layla", "bashful")\n\t\tPlayer: Let's go, then?""", """\t\tdo actor_change("Layla", "bashful")\n\t\tdo actor_change("Fiona", "base")\n\t\tPlayer: Let's go, then?"""),
	("""Player: Well, you don't have much of a choice, you see?""", """do actor_change("Fiona", "suspicious")\nPlayer: Well, you don't have much of a choice, you see?"""),
	("""Player: We did some looking around, and we came across this lil thing.""", """do actor_change("Fiona", "explain")\nPlayer: We did some looking around, and we came across this lil thing."""),
	("""Player: We know what's in it, and we know what kind of a man you are.""", """do actor_change("Fiona", "suspicious")\nPlayer: We know what's in it, and we know what kind of a man you are."""),
	("""Player: On your way, Jayce.""", """do actor_change("Fiona", "base")\nPlayer: On your way, Jayce."""),
	("""\t\tdo actor_change("Layla", "neutral")\n\t\tPlayer: I just did what I had to do to get things going our way, Layla.""", """\t\tdo actor_change("Layla", "neutral")\n\t\tdo actor_change("Fiona", "shrug")\n\t\tPlayer: I just did what I had to do to get things going our way, Layla."""),
	("""\t\tPlayer: Don't mention it.""", """\tdo actor_change("Fiona", "base")\n\tPlayer: Don't mention it."""),
	("""\t\tdo actor_change("Layla", "eager")\n\t\tPlayer: I just did what I had to do to get things going our way, Layla.""", """\t\tdo actor_change("Layla", "eager")\n\t\tdo actor_change("Fiona", "shrug")\n\t\tPlayer: I just did what I had to do to get things going our way, Layla."""),
	("""\t\t\tPlayer: Sorry?""", """\t\t\tdo actor_change("Fiona", "suspicious")\n\t\t\tPlayer: Sorry?"""),
	("""\t\t\tPlayer: Heh. If you say so.""", """\t\tdo actor_change("Fiona", "base")\n\t\t\tPlayer: Heh. If you say so."""),
	("""\t\t\tPlayer: Heh. If you say so.\n\t\tPlayer: Anyway, let's go?""", """\t\t\tPlayer: Heh. If you say so.\n\t\tdo actor_change("Fiona", "base")\n\t\tPlayer: Anyway, let's go?"""),
	("""Player: (I don't like his tone...)""", """do actor_change("Fiona", "suspicious")\nPlayer: (I don't like his tone...)"""),
	("""Player: You know what? Never mind.""", """do actor_change("Fiona", "base")\nPlayer: You know what? Never mind."""),
	("""\tPlayer: Oh, we'll MAKE him.""", """\tdo actor_change("Fiona", "suspicious")\n\tPlayer: Oh, we'll MAKE him."""),
	("""\tPlayer: Let's think... where would a janitor keep his belongings in this building?""", """\tdo actor_change("Fiona", "thinking")\n\tPlayer: Let's think... where would a janitor keep his belongings in this building?"""),
	("""\tPlayer: Absolutely. I hate his guts.""", """\tdo actor_change("Fiona", "suspicious")\n\tPlayer: Absolutely. I hate his guts."""),
	("""\tPlayer: Hell yeah. Let's go.""", """\tdo actor_change("Fiona", "base")\n\tPlayer: Hell yeah. Let's go.""")
]
apply_edits('dialogue/guard_lab.dialogue', t4_edits, is_crlf=False)

# Task 5
t5_edits = [
	("""Player: Well, for us at the genomics lab, the biochem department poses a real threat.""", """do actor_change("Fiona", "explain")\nPlayer: Well, for us at the genomics lab, the biochem department poses a real threat."""),
	("""Player: Tell me about it. """, """do actor_change("Fiona", "base")\nPlayer: Tell me about it. """),
	("""\tPlayer: I'd suggest you not worry too much about it.""", """\tdo actor_change("Fiona", "hands_back")\n\tPlayer: I'd suggest you not worry too much about it."""),
	("""\tPlayer: Yeah... an undergrad RA holds basically no standing amongst grad students.""", """\tdo actor_change("Fiona", "shrug")\n\tPlayer: Yeah... an undergrad RA holds basically no standing amongst grad students."""),
	("""\tPlayer: (... she's gone quiet.)""", """\tdo actor_change("Fiona", "hands_back_sad")\n\tPlayer: (... she's gone quiet.)"""),
	("""Player: Right. Anyway, I don't like him much.""", """do actor_change("Fiona", "base")\nPlayer: Right. Anyway, I don't like him much."""),
	("""Player: He's good at his work though. Annoyingly.""", """do actor_change("Fiona", "shy")\nPlayer: He's good at his work though. Annoyingly."""),
	("""Player: (I suppose he did say something about some wrong numbers getting signed off...)""", """do actor_change("Fiona", "thinking")\nPlayer: (I suppose he did say something about some wrong numbers getting signed off...)"""),
	("""Player: Don't know.""", """do actor_change("Fiona", "base")\nPlayer: Don't know.""")
]
apply_edits('dialogue/julian_intro.dialogue', t5_edits, is_crlf=False)

# Task 6
t6_edits = [
	("""What do you want to say to him?""", """do actor_change("Fiona", "base")\nWhat do you want to say to him?"""),
	("""Player: Saw you talking pretty intensely over the phone.""", """do actor_change("Fiona", "hands_back")\nPlayer: Saw you talking pretty intensely over the phone."""),
	("""Player: Right. Carry on, then.""", """do actor_change("Fiona", "base")\nPlayer: Right. Carry on, then."""),
	("""Player: Listen. Seems like someone changed our lab's password yesterday.""", """do actor_change("Fiona", "hands_back")\nPlayer: Listen. Seems like someone changed our lab's password yesterday."""),
	("""Player: Yeah. Unfortunately, that isn't working anymore.""", """do actor_change("Fiona", "base")\nPlayer: Yeah. Unfortunately, that isn't working anymore."""),
	("""Player: (This cheeky bastard.)""", """do actor_change("Fiona", "suspicious")\nPlayer: (This cheeky bastard.)"""),
	("""Player: Oh no! How could I have ever heard of that?""", """do actor_change("Fiona", "shrug")\nPlayer: Oh no! How could I have ever heard of that?"""),
	("""Player: It's not like I'm the youngest lead researcher under the most celebrated genomicist in the world.""", """do actor_change("Fiona", "explain")\nPlayer: It's not like I'm the youngest lead researcher under the most celebrated genomicist in the world."""),
	("""You almost crack a smile. Almost.""", """do actor_change("Fiona", "shy")\nYou almost crack a smile. Almost."""),
	("""Player: Anyway, do you think you could search for those dates quickly on your phone?""", """do actor_change("Fiona", "hands_back")\nPlayer: Anyway, do you think you could search for those dates quickly on your phone?"""),
	("""\tPlayer: That's none of your business.""", """\tdo actor_change("Fiona", "suspicious")\n\tPlayer: That's none of your business."""),
	("""\tJulian: Good luck finding your dates.\n\tdo actor_change("Julian", "base")\n\tPlayer: Yeah, well. Whatever.""", """\tJulian: Good luck finding your dates.\n\tdo actor_change("Julian", "base")\n\tdo actor_change("Fiona", "base")\n\tPlayer: Yeah, well. Whatever."""),
	("""\tPlayer: Fine. Layla has some sequencing—""", """\tdo actor_change("Fiona", "base")\n\tPlayer: Fine. Layla has some sequencing—"""),
	("""\tPlayer: Hmm. Sorry, I forgot. We can't tell you.""", """\tdo actor_change("Fiona", "hands_back_sad")\n\tPlayer: Hmm. Sorry, I forgot. We can't tell you."""),
	("""\tdo actor_change("Julian", "base")\n\tPlayer: Yeah, well. Whatever.""", """\tdo actor_change("Julian", "base")\n\tdo actor_change("Fiona", "base")\n\tPlayer: Yeah, well. Whatever."""),
	("""\t\tPlayer: I know. It slipped out. My bad.""", """\tdo actor_change("Fiona", "hands_back_sad")\n\t\tPlayer: I know. It slipped out. My bad."""),
	("""\t\tPlayer: Relax. He didn't get anything out of us.""", """\tdo actor_change("Fiona", "base")\n\t\tPlayer: Relax. He didn't get anything out of us."""),
	("""\t\tPlayer: I know him...""", """\tdo actor_change("Fiona", "shy")\n\t\tPlayer: I know him..."""),
	("""\tPlayer: Can't get on the internet. Yes.""", """\tdo actor_change("Fiona", "base")\n\tPlayer: Can't get on the internet. Yes."""),
	("""\tPlayer: Hmm... I'm not sure.""", """\tdo actor_change("Fiona", "thinking")\n\tPlayer: Hmm... I'm not sure."""),
	("""\tPlayer: Yep.""", """\tdo actor_change("Fiona", "base")\n\tPlayer: Yep.""")
]
apply_edits('dialogue/julian_talk.dialogue', t6_edits, is_crlf=False)

# Task 7
t7_edits = [
	("""Player: Do you wanna quickly google the things Julian mentioned?""", """do actor_change("Fiona", "explain")\nPlayer: Do you wanna quickly google the things Julian mentioned?"""),
	("""Player: Uh-huh.""", """do actor_change("Fiona", "base")\nPlayer: Uh-huh."""),
	("""Player: Oh... wow.""", """do actor_change("Fiona", "suspicious")\nPlayer: Oh... wow."""),
	("""Player: Check this out.""", """do actor_change("Fiona", "explain")\nPlayer: Check this out."""),
	("""Player: Yep.""", """do actor_change("Fiona", "base")\nPlayer: Yep."""),
	("""Player: Anyway, lemme figure out what to do with this.""", """do actor_change("Fiona", "thinking")\nPlayer: Anyway, lemme figure out what to do with this.""")
]
apply_edits('dialogue/supply_room.dialogue', t7_edits, is_crlf=True)

# Task 8
t8_edits = [
	("""Player: This seems to be locked as well.""", """do actor_change("Fiona", "suspicious")\nPlayer: This seems to be locked as well."""),
	("""Player: Welp. Let's go ask him then.""", """do actor_change("Fiona", "base")\nPlayer: Welp. Let's go ask him then."""),
	("""Player: You know what?""", """do actor_change("Fiona", "explain")\nPlayer: You know what?"""),
	("""Player: It'll be fine. I'll be in and out in a second.""", """do actor_change("Fiona", "base")\nPlayer: It'll be fine. I'll be in and out in a second.""")
]
apply_edits('dialogue/greene_office.dialogue', t8_edits, is_crlf=True)
