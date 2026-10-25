extends RefCounted
## Pure interpretation. No scene access, inventory mutation or hidden knowledge.

static func normalize(raw: String) -> String:
	var result := ""
	var source := raw.left(512).to_lower()
	for index in source.length():
		var character := String.chr(source.unicode_at(index))
		result += character if character.is_valid_identifier() or character.is_valid_int() else " "
	return " ".join(result.split(" ", false))

static func contains_phrase(text: String, phrase: String) -> bool:
	return (" " + text + " ").contains(" " + phrase + " ")

static func parse(raw: String) -> Dictionary:
	var text := normalize(raw)
	if text.is_empty(): return {"intent":"empty", "text":text}
	# Exact conversational requests cannot swallow physical commands or article nouns.
	var direct := {
		"i don t know":"hesitate", "i can t decide":"hesitate", "i need a moment":"hesitate",
		"your printer is jammed":"jam", "the paper is stuck":"jam",
		"xyzzy":"magic", "plugh":"magic", "abracadabra":"magic",
		"undo":"undo", "undo that":"undo", "sing":"sing", "sing me a song":"sing",
		"tell me a joke":"joke", "another joke":"joke", "wait":"wait", "wait here":"wait",
		"can we be quiet":"silence", "do we have to talk":"silence",
		"fuck off":"leave", "go fuck yourself":"rude"
	}
	if direct.has(text): return {"intent":str(direct[text]), "text":text}
	var groups := {
		"leave":["goodbye", "bye", "stop talking", "leave me alone", "quiet please"],
		"inventory":["inventory", "what am i carrying", "what do i have", "check my bag"],
		"remember":["remember", "recall", "what did we discuss", "what did i ask"],
		"help":["help", "what should i do", "what now", "i am stuck", "i m stuck"],
		"identity":["what are you", "who are you", "your name"],
		"alive":["are you alive", "are you real", "conscious", "sentient"],
		"fear":["are you afraid", "i am afraid", "i m scared", "i am scared"],
		"care":["thank you", "thanks", "are you okay", "are you all right", "how are you", "how do you feel"],
		"newspaper":["newspaper", "newspapers", "today s paper", "the news"],
		"weather":["weather", "forecast", "rain", "snow", "storm"],
		"eat":["eat", "swallow", "lick", "taste"],
		"look":["look around", "look", "what is here", "where am i", "where are we"],
		"examine":["examine", "inspect", "look at", "describe", "tell me about"],
		"navigate":["where is", "where can i find", "take me", "how do i get", "directions"],
		"use":["use", "open", "close", "unlock", "repair", "fix", "turn on", "turn off", "give", "take"],
		"ask":["ask", "why", "how", "what", "who", "tell"]
	}
	# Specific descriptions outrank the broad LOOK verb.
	if contains_phrase(text, "look at"): return {"intent":"examine", "text":text}
	for intent: String in groups:
		for phrase: String in groups[intent]:
			if contains_phrase(text, phrase): return {"intent":intent, "text":text}
	return {"intent":"unknown", "text":text}

static func candidates(text: String, visible: Array) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var best_score := 0
	for value: Variant in visible:
		if value is not Dictionary: continue
		var object: Dictionary = value
		if str(object.get("id", "")).is_empty(): continue
		var aliases: Array = object.get("aliases", []).duplicate()
		aliases.append(str(object.get("name", "")))
		var score := 0
		for alias: Variant in aliases:
			var key := normalize(str(alias))
			if not key.is_empty() and contains_phrase(text, key):
				score = maxi(score, key.length())
		if score > best_score:
			found.clear()
			best_score = score
		if score > 0 and score == best_score: found.append(object)
	return found
