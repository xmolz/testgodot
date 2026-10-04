# library_books.gd — the text of every readable library book (BookReader shows one spread each).
# right page: title, author, page, heading and body (body accepts BBCode, e.g. [b]bold[/b]).
# left page: "image" (a res:// path) and an optional "caption". leave image out for a title plate.
# keep bodies short (about 60-90 words) so they fit the right page at a large, phone-readable size.
# the shelf menus that open these live in dialogue/library_books.dialogue.
extends RefCounted

const BOOKS := {
	# ---------------- left stand, row 1: Scientific History
	"history_of_heredity": {
		"title": "Threads of Inheritance: A History of Heredity",
		"author": "M. Albrecht",
		"page": "p. 112",
		"heading": "The Forgotten Discovery",
		"body": """Long before the double helix, a young Swiss physician named [b]Friedrich Miescher[/b] (born [b]13 August 1844[/b], Basel) isolated a strange, phosphorus-rich substance from the nuclei of white blood cells, scraped from used surgical bandages.

Working in Tübingen in [b]1869[/b], he called it nuclein. His findings were finally published in [b]1871[/b].

Nuclein is what we now call DNA. Miescher died on [b]26 August 1895[/b], decades before anyone understood what he had found.""",
	},
	"race_for_the_helix": {
		"title": "Twisted Ladders: The Race for DNA",
		"author": "R. Okafor",
		"page": "p. 58",
		"heading": "Spring, 1953",
		"body": """On [b]28 February 1953[/b], James Watson and Francis Crick settled on a model of DNA as a double helix. Their one-page paper appeared in Nature on [b]25 April 1953[/b].

The model leaned heavily on X-ray work from King's College London, including Rosalind Franklin's famous Photo 51.

In 1962, Watson, Crick and Maurice Wilkins shared the Nobel Prize. Franklin had died in 1958, and the prize is never awarded posthumously.""",
	},
	# ---------------- left stand, row 2: Genetics & Molecular Biology
	"darwin_origin": {
		"title": "On the Origin of Species",
		"author": "Charles Darwin",
		"page": "Ch. I, 1859",
		"heading": "Variation under Domestication",
		"body": """The laws governing inheritance are quite unknown; no one can say why the same peculiarity in different individuals of the same species, and in individuals of different species, is sometimes inherited and sometimes not so; why the child often reverts in certain characters to its grandfather or grandmother or other much more remote ancestor; why a peculiarity is often transmitted from one sex to both sexes or to one sex alone, more commonly but not exclusively to the like sex.""",
	},
	"sequencing_handbook": {
		"title": "The Bench Guide to Sequencing",
		"author": "Genomics Core Facility",
		"page": "p. 3",
		"heading": "",
		"body": """Rule one: label everything. Rule two: label it again. Rule three: never assume the run worked until you have looked at the quality scores yourself.""",
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
	"conservation_of_mass": {
		"title": "Nothing Is Lost",
		"author": "C. Marchetti",
		"page": "p. 21",
		"image": "res://Backgrounds/Kit/Faculty Offices/science_painting.jpg",
		"caption": "Antoine and Marie-Anne Lavoisier. Jacques-Louis David, 1788.",
		"heading": "",  # TEMPLATE — developer may rewrite this book
		"body": """Antoine Lavoisier weighed everything before and after it burned, and showed that matter is neither created nor destroyed, only transformed. His wife, Marie-Anne, recorded the experiments and drew the apparatus.""",
	},
	"lab_safety": {
		"title": "Laboratory Safety, 9th Edition",
		"author": "University Safety Office",
		"page": "p. 1",
		"heading": "",  # TEMPLATE — developer may rewrite this book
		"body": """Eye protection is mandatory at all times. Food and drink are not permitted in any laboratory. Sleeping in the laboratory is strongly discouraged.""",
	},
	# ---------------- left stand, row 4: Statistics & Mathematics
	"p_values": {
		"title": "The Trouble with P-Values",
		"author": "D. Berger",
		"page": "p. 44",
		"heading": "",  # TEMPLATE — developer may rewrite this book
		"body": """A p-value does not tell you the probability that your hypothesis is true. It tells you how surprising your data would be if it were false. Most arguments in the department begin with forgetting this.""",
	},
	"numbers_for_biologists": {
		"title": "Numbers for Nervous Biologists",
		"author": "P. Huang",
		"page": "p. 7",
		"heading": "",  # TEMPLATE — developer may rewrite this book
		"body": """If you are reading this, someone has asked you to compute a standard deviation. Do not panic.""",
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
	"rembrandt_light": {
		"title": "Rembrandt and the Light",
		"author": "E. de Vries",
		"page": "p. 63",
		"image": "res://Backgrounds/Kit/Faculty Offices/humanities_painting.jpg",
		"caption": "Aristotle with a Bust of Homer. Rembrandt, 1653.",
		"heading": "",  # TEMPLATE — developer may rewrite this book
		"body": """In Aristotle with a Bust of Homer, the philosopher's hand rests on the poet's head while his other hand touches a gold chain. Fame earned, and fame given. Rembrandt leaves it to us to decide which matters more.""",
	},
	"campus_buildings": {
		"title": "Brick and Glass: The Buildings of Greendale",
		"author": "Greendale Press",
		"page": "p. 15",
		"heading": "",  # TEMPLATE — developer may rewrite this book
		"body": """The science block was extended twice in the last decade, both times with private donations. The newer wing's elevator, sadly, was not part of either renovation.""",
	},
	# ---------------- right stand, row 4: University History
	"greendale_history": {
		"title": "A History of Greendale University",
		"author": "Greendale Archives",
		"page": "p. 201",
		"heading": "",  # TEMPLATE — developer may rewrite this book
		"body": """In recent years the university's research has grown rapidly, supported by the patronage of its Advisory Board and its chairman, Mr. Leon Voss.""",
	},
	"yearbook": {
		"title": "Greendale Yearbook",
		"author": "Student Union",
		"page": "p. 77",
		"heading": "",  # TEMPLATE — developer may rewrite this book
		"body": """Rows of smiling graduate students. Someone has drawn a moustache on one of them.""",
	},
}
