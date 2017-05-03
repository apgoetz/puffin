# awk library to parse config file


# if we are in find_sec look for things that match brackets

# remove comment lines
/^[:space:]*#/ {next}

match($0, /\[.*\]/) {
	section = substr($0, (RSTART + 1), (RLENGTH - 2))
	# if we have encountered a new rule
	if (section != "_Renderers") {
		if (section in rules) {
			die("Error Parsing config @ line " FNR ": encountered section " section " multiple times")
		} else {
			rules[section] = ""
		}
	}
	next
}

# if we detect a setting of a key value
/.*=.*/ {
	
	# special exception for renderer: we use this to store converters
	if (section == "_Renderers") {
		renderers = renderers $0 "\n"
	} else { 		# we are parsing a rule
		rules[section] = rules[section] $0 "\n"
	} 
}



# parses the multiline string in a rule into array
# ruletext is string to parse
# dest_array is used to return results
function parse_rule(ruletext, dest_array) {
	delete dest_array
	n_rules = split(ruletext, lines, "\n")
	for (i = 1; i <= n_rules; i++) {
		l = lines[i]
		if (l=="") {continue}
		n = split(l, kval, "=")
		if (n != 2) {
			die("Error Parsing config @ line " FNR ": Bad key val " l " n == " n)
		}
		dest_array[kval[1]] = kval[2]
	}
}

# helper function to print all of the rules identified during the configuration
function dump_rules() {
	print "RULES"
	for (r in rules) {
		print "RULE:" r
		parse_rule(rules[r],rule_vals)
		for (k in rule_vals) 
			print k ,"->", rule_vals[k]
	}
}

function die(message) {
	print message >  "/dev/fd/2"
	HAS_DIED="true"
	exit -1
}
