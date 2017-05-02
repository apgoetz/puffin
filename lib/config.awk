# awk library to parse config file


# if we are in find_sec look for things that match brackets
match($0, /\[([[:alnum:]_]).*\]/) {
  section = substr($0, (RSTART + 1), (RLENGTH - 2))

  # if we have encountered a new rule
  if (section != "RENDERERS") {
	  if (section in section_names) {
		  print "Error Parsing config @ line", FNR ": encountered section", section, "multiple times"
		exit -1
	  } else {
		  section_names[section] = 1
	  }
  }
  next
}

# if we detect a setting of a key value
/.*=.*/ {
	n = split($0, kval, "=")
	if (n != 2) {
		print "Error Parsing config @ line", FNR ": Bad key val", $0
		exit -1
	}

	key = kval[1]
	val = kval[2]
	
	# special exception for renderer: we use this to store converters
	if (section == "RENDERERS") {
		renderers[key] = val
	} else { 		# we are parsing a rule
		rules[section,key] = val
	} 
}

# helper function to print all of the rules identified during the configuration
function dump_rules() {
	print "RULES"
	for (r in rules) {
		split(r,sep,SUBSEP)
		print "PATH",sep[1] ",", sep[2], "->", rules[r]

	}
}
