# library_books.gd — the text of every readable library book (BookReader shows one spread each).
# right page: title, author, page, heading and body (body accepts BBCode, e.g. [b]bold[/b]).
# left page: "image" (a res:// path) and an optional "caption". leave image out for a title plate.
# keep bodies short (about 60-90 words) so they fit the right page at a large, phone-readable size.
# the shelf menus that open these live in dialogue/library_books.dialogue.
extends RefCounted

const BOOKS := {
	# ---------------- Dr. Greene's office shelf (menu: dialogue/library_books.dialogue, ~ greene_shelf)
	"la_marr_biography": {
		"title": "Barbara La Marr: A Life in Silent Film",
		"author": "Cindy Barton",
		"heading": "The Girl Who Was Too Beautiful",
		"image": "res://Backgrounds/Kit/Faculty Offices/Greene Office/barbara_portrait.png",
		"caption": "Barbara La Marr.",
		"pages": [
			"""Barbara La Marr (born Reatha Dale Watson) was born in [b]1896[/b] in Yakima, Washington. As a child, she acted in stock company plays.

As a girl in her teens, she moved to Los Angeles and worked as a dancer in cafes and cabarets. By the age of 17, she had already been married once, and claimed an earlier marriage that was never verified.""",
			"""She then became a writer and wrote for films, until actor and filmmaker Douglas Fairbanks decided she belonged in front of the camera.

She featured in about two dozen films in about five years, including classics such as The Three Musketeers, The Prisoner of Zenda and The White Moth. Her work was widely praised by critics and fans alike.""",
			"""Despite her rise as a prominent Hollywood actress, she never quit writing poetry.

Unfortunately, due to health complications, she died at the young age of 29. Around 120,000 mourners reportedly came to see her lie in state. It was a big loss for the nation.

Her beauty, talent and compassion survive through her work.""",
		],
	},
	"she_has_her_mothers_laugh": {
		"title": "She Has Her Mother's Laugh",
		"author": "Carl Zimmer",
		"pages": [
			"""One reason that cells break down bone is that in old age they make less of a protein called TERT. In 2012, researchers at the Spanish National Cancer Research Centre coaxed old mice to make extra TERT by giving them an extra copy of the gene. Their osteoporosis reversed, and their bones strengthened.""",
			"""It’s conceivable that doctors could use CRISPR gene therapy to treat people as well. CRISPR molecules would home in on the TERT gene in bone cells and edit it. The gene would behave as it did when the patients were younger, strengthening their bones.""",
			"""But gene therapy for TERT could do a lot of other kinds of good, too. The Spanish researchers who tried it out on mice found that it also reversed aging in their muscles, their brains, and their blood. It extended the life span of old mice by 13 percent. When the scientists treated younger mice with TERT gene therapy, the animals lived 24 percent longer.""",
		],
	},
	# ---------------- left stand, row 1: Scientific History
	"history_of_heredity": {
		"title": "Threads of Inheritance: A History of Heredity",
		"author": "Fred G. Mann",
		"heading": "The Forgotten Discovery",
		"page_flags": {2: "miescher_book_date_seen"},
		"pages": [
			"""The discovery of DNA is often attributed to James Watson and Francis Crick, winners of the 1962 Nobel Prize.

However, that is a misconception. What Watson and Crick discovered, on [b]February 28, 1953[/b], was actually DNA's double-helix structure.""",
			"""The actual discovery was made by the Swiss physiological chemist [b]Friedrich Miescher[/b] (born [b]August 13, 1844[/b]), when he first identified what he called "nuclein" inside the nuclei of human white blood cells. (The term "nuclein" was later changed to "nucleic acid," and eventually to "deoxyribonucleic acid," or "DNA.")""",
			"""Right after making the discovery, he sent a letter to his uncle describing it. The letter was dated [b]February 26, 1869[/b].

Miescher died on [b]August 26, 1895[/b], decades before anyone truly understood what he had found.""",
		],
	},
	"darwin_beagle": {
		"title": "The Voyage of the Beagle",
		"author": "Charles Darwin",
		"heading": "Chapter XVII: Galapagos Archipelago",
		"pages": [
			"""The natural history of these islands is eminently curious, and well deserves attention. Most of the organic productions are aboriginal creations, found nowhere else; there is even a difference between the inhabitants of the different islands; yet all show a marked relationship with those of America, though separated from that continent by an open space of ocean, between 500 and 600 miles in width.""",
			"""The archipelago is a little world within itself, or rather a satellite attached to America, whence it has derived a few stray colonists, and has received the general character of its indigenous productions. Considering the small size of these islands, we feel the more astonished at the number of their aboriginal beings, and at their confined range.""",
			"""Seeing every height crowned with its crater, and the boundaries of most of the lava-streams still distinct, we are led to believe that within a period, geologically recent, the unbroken ocean was here spread out. Hence, both in space and time, we seem to be brought somewhat near to that great fact—that mystery of mysteries—the first appearance of new beings on this earth.""",
		],
	},
	# ---------------- left stand, row 2: Genetics & Molecular Biology
	"morgan_heredity": {
		"title": "The Physical Basis of Heredity",
		"author": "Thomas Hunt Morgan",
		"heading": "Chapters I and II",
		"pages": [
			"""That the fundamental aspects of heredity should have turned out to be so extraordinarily simple supports us in the hope that nature may, after all, be entirely approachable. Her much-advertised inscrutability has once more been found to be an illusion due to our ignorance. This is encouraging, for, if the world in which we live were as complicated as some of our friends would have us believe we might well despair that biology could ever become an exact science.""",
			"""Mendel succeeded in discovering the principle of segregation because he simplified the conditions of his experiments so that he had to deal with one process at a time. Others before him had failed because they worked with too complex a situation. … To Mendel's foresight in arranging the conditions of his work, as much as to his astuteness in interpreting the data, is due his remarkable success.""",
		],
	},
	"grad_safety_guidelines": {
		"title": "Safety Guidelines for Overworked Grad Students",
		"author": "Greendale Graduate Student Association",
		"page": "p. 1",
		"heading": "",
		"body": """Whatever you do in your life as a grad student, you must never engage in these practices:

1) Being cruel to your test subjects, especially if they are mice.
2) Forgetting to wash your hands after running experiments, even if you were wearing gloves.
3) Sleeping in the lab (do it in the library instead, where the environment is safer).""",
	},
	# ---------------- left stand, row 3: Chemistry
	"faraday_candle": {
		"title": "The Chemical History of a Candle",
		"author": "Michael Faraday",
		"heading": "Lecture I",
		"pages": [
			"""I purpose, in return for the honour you do us by coming to see what are our proceedings here, to bring before you, in the course of these lectures, the Chemical History of a Candle. … There is not a law under which any part of this universe is governed which does not come into play, and is touched upon in these phenomena. There is no better, there is no more open door by which you can enter into the study of natural philosophy, than by considering the physical phenomena of a candle.""",
			"""We come here to be philosophers; and I hope you will always remember that whenever a result happens, especially if it be new, you should say, “What is the cause? Why does it occur?” and you will in the course of time find out the reason.""",
			"""You have the glittering beauty of gold and silver, and the still higher lustre of jewels, like the ruby and diamond; but none of these rival the brilliancy and beauty of flame. What diamond can shine like flame? It owes its lustre at night-time to the very flame shining upon it. The flame shines in darkness, but the light which the diamond has is as nothing until the flame shine upon it, when it is brilliant again. The candle alone shines by itself, and for itself, or for those who have arranged the materials.""",
		],
	},
	"ignition": {
		"title": "Ignition!",
		"author": "John D. Clark",
		"heading": "An Informal History of Liquid Rocket Propellants",
		"pages": [
			"""The absolute limit to the performance of a chemical rocket, even in space, appears to be somewhere below 600 seconds. This is a frustrating situation, and various far-out methods of cracking this barrier have been suggested. One is to use free radicals or unstable species as propellants, and to use the energy of their reversion to the stable state for propulsion.""",
			"""For instance, when two atoms of hydrogen combine to form one molecule of H2, some 100 kilocalories of energy are released per two-gram mole. This means that a 50-50 (by weight) mixture of monatomic hydrogen and ordinary hydrogen would have a performance of some 1000-1100 seconds.""",
			"""That is, it would if (A) you could make that much monatomic hydrogen and could mix it with ordinary hydrogen and (B) if you could keep it from reverting immediately to H2 - in a catastrophic manner. So far, nobody has the foggiest idea of how to do either one.""",
		],
	},
	# ---------------- left stand, row 4: Statistics & Mathematics
	"power_of_placebos": {
		"title": "The Power of Placebos",
		"author": "Jeremy Howick",
		"pages": [
			"""The opposite happens when doctors use negative words. This has been demonstrated in studies of positive and negative framing. In one recent example, 203 healthy adult volunteers were each given a placebo pill described as “a well-known tablet available without prescription.”""",
			"""They were randomized to receive information presented in one of two ways. Some were told that side effects were common, affecting 1 in 10 people. The side-effect rates were “positively framed” to the others, who were told that the side effects were uncommon and that 90% of people would not be affected. Those who received the positively framed information reported slightly fewer side effects.""",
			"""A related study published in 2003 looked at what happened to patients who were each hooked up to an intravenous line that was supplying painkilling morphine. When the doctors stopped the morphine, they only told some of the patients. The patients who were told the morphine would stop had a faster onset of pain. Other studies have reported similar findings.""",
		],
	},
	"pearson_grammar": {
		"title": "The Grammar of Science",
		"author": "Karl Pearson",
		"heading": "Chapter I: Introductory",
		"pages": [
			"""Now this is the peculiarity of scientific method, that when once it has become a habit of mind, that mind converts all facts whatsoever into science. The field of science is unlimited; its material is endless, every group of natural phenomena, every phase of social life, every stage of past or present development is material for science. The unity of all science consists alone in its method, not in its material.""",
			"""The man who classifies facts of any kind whatever, who sees their mutual relation and describes their sequences, is applying the scientific method and is a man of science. The facts may belong to the past history of mankind, to the social statistics of our great cities, to the atmosphere of the most distant stars, to the digestive organs of a worm, or to the life of a scarcely visible bacillus. It is not the facts themselves which form science, but the method in which they are dealt with.""",
			"""Hundreds of men have allowed their imagination to solve the universe, but the men who have contributed to our real understanding of natural phenomena have been those who were unstinting in their application of criticism to the product of their imaginations. It is such criticism which is the essence of the scientific use of the imagination, which is, indeed, the very life-blood of science.""",
			"""No less an authority than Faraday writes:

“The world little knows how many of the thoughts and theories which have passed through the mind of a scientific investigator have been crushed in silence and secrecy by his own severe criticism and adverse examination; that in the most successful instances not a tenth of the suggestions, the hopes, the wishes, the preliminary conclusions have been realised.”""",
		],
	},
	# ---------------- right stand, row 1: Literature & Classics
	"homer_odyssey": {
		"title": "The Odyssey",
		"author": "Homer, trans. S. Butler",
		"page": "Book I",
		"heading": "",
		"body": """Tell me, O muse, of that ingenious hero who travelled far and wide after he had sacked the famous town of Troy. Many cities did he visit, and many were the nations with whose manners and customs he was acquainted; moreover he suffered much by sea while trying to save his own life and bring his men safely home; but do what he might he could not save his men, for they perished through their own sheer folly in eating the cattle of the Sun-god Hyperion; so the god prevented them from ever reaching home.""",
	},
	"shelley_frankenstein": {
		"title": "Frankenstein",
		"author": "Mary Shelley",
		"page": "Ch. 5",
		"heading": "",
		"body": """It was on a dreary night of November that I beheld the accomplishment of my toils. With an anxiety that almost amounted to agony, I collected the instruments of life around me, that I might infuse a spark of being into the lifeless thing that lay at my feet. It was already one in the morning; the rain pattered dismally against the panes, and my candle was nearly burnt out, when, by the glimmer of the half-extinguished light, I saw the dull yellow eye of the creature open; it breathed hard, and a convulsive motion agitated its limbs.""",
	},
	# ---------------- right stand, row 2: Philosophy
	"plato_republic": {
		"title": "The Republic",
		"author": "Plato, trans. B. Jowett",
		"page": "Book II",
		"heading": "The Ring of Gyges",
		"body": """Suppose now that there were two such magic rings, and the just put on one of them and the unjust the other; no man can be imagined to be of such an iron nature that he would stand fast in justice. … And this we may truly affirm to be a great proof that a man is just, not willingly or because he thinks that justice is any good to him individually, but of necessity, for wherever any one thinks that he can safely be unjust, there he is unjust.""",
	},
	"mill_utilitarianism": {
		"title": "Utilitarianism",
		"author": "John Stuart Mill",
		"page": "Ch. V, 1863",
		"heading": "On the Connexion between Justice and Utility",
		"body": """…it is universally considered just that each person should obtain that (whether good or evil) which he deserves; and unjust that he should obtain a good, or be made to undergo an evil, which he does not deserve. This is, perhaps, the clearest and most emphatic form in which the idea of justice is conceived by the general mind. As it involves the notion of desert, the question arises, what constitutes desert?""",
	},
	# ---------------- right stand, row 3: Art & Architecture
	"the_artists_reality": {
		"title": "The Artist's Reality",
		"author": "Mark Rothko",
		"pages": [
			"""In art, as in biology, there is a phenomenon that can be described as mutation, in which appearances radically change at a tempo much more rapid than that at which they normally proceed. As in the case of biology, we have no means to determine the process by which this radical change occurs.""",
			"""Yet we do know that it is a reaction to a form of congestion. It is a desperate change due to the arrival at a point where the corollaries to a situation are exhausted, when the stimulus to additional growth is sluggish and a rapid rejuvenation is needed so that art, through disuse, does not atrophy in much the same way as an unused human organ.""",
			"""Here art must attain a new start if it is to survive. Then, assiduously, it renews its traditions by marriage with alien traditions, by the reexamination of its own processes, and by those means reestablishes contact again with its own roots. It is in this way that new plastic worlds are born.""",
			"""For art, like a race, cannot inbreed very long without losing its incentives to continue; it needs the rejuvenation of new experiences and new blood. These mutations, it must be clear, however, do not constitute a change in properties, or mean that art has discarded its past. On the contrary, mutation involves a more conscious evaluation of art’s inheritance and the redirection of that inheritance into channels where it can be continued with greater force.""",
		],
	},
	"poetics_of_space": {
		"title": "The Poetics of Space",
		"author": "Gaston Bachelard, trans. Maria Jolas",
		"pages": [
			"""We comfort ourselves by reliving memories of protection. Something closed must retain our memories, while leaving them their original value as images. Memories of the outside world will never have the same tonality as those of home and, by recalling these memories, we add to our store of dreams; we are never real historians, but always near poets, and our emotion is perhaps nothing but an expression of a poetry that was lost.""",
		],
	},
	# ---------------- right stand, row 4: University History
	"greendale_history": {
		"title": "A History of Greendale University",
		"author": "Greendale Archives",
		"heading": "The Founding",
		"pages": [
			"""Greendale University of Science and Arts was founded on October 14, 1786.

It is the seventh-oldest institution of higher education in the United States, and was one of the first in the country to admit students regardless of their religious affiliation.""",
			"""The university was founded by two brothers, Moses and John Taylor.

After a sailing accident aboard a slave ship, the two came away with differing views on slavery. Calling slavery an overall good for the American economy, John left the university and took his funds with him.""",
			"""The university was on the brink of collapse, until it found support in a $5,000 donation from a philanthropist and businessman: Vaughn Voss.

His family continues to be associated with Greendale to this day.""",
		],
	},
}
