# render an output file based on commands in the adt

# populates date if necessary
function add_date(rules, filepath,     year, month, day) {
	if (! ("Date") in rules) {
		# need to use ls -l because this is the only POSIX way to get time modified
		("ls -l " filepath) | getline
		month = $6
		day = $7
		if ($8 ~ /:/) {
			"date +%Y" | getline
			year = $0
		} else {
			year = $8
		}
		rules["Date"] = month " " day " " year
	}
}

function add_autovars(rules, filepath,     n, fileparts, filename, ext, words, i) {
	n = split(filepath, fileparts, "/")
	filename = fileparts[n]
	n = split(filename, fileparts, ".")
	ext = fileparts[n] # populate extension

	rules["filename"] = filepath
	
	# populate title if not set
	if (! ("Title" in rules)) {
		n = split(fileparts[1], words, /[^ -_]/)
		for (i in words) {
			words[i] = toupper(substr(words[i], 1, 1)) substr(words[i], 2)
		}
		rules["Title"] = join(words, 1, n, " ")
	}

	# populate date
	add_date(rules, filepath)

	# populate permalink
	if (! ("Permalink" in rules)) {
		n = split(filepath, fileparts, ".")
		rules["Permalink"] = join(fileparts, 1, n-1, ".")
		if (ext == rules["src_ext"]) {
			rules["Permalink"] = rules["Permalink"] rules["dest_ext"]
		} else {
			rules["Permalink"] = rules["Permalink"] ext
		}
	}
}

END {

	if (HAS_DIED=="true") {
		exit -1
	}
	
	# get the rules that apply to the file we are parsing
	get_rules(adt, filename, rules)
	
	if (rules["action"] == "convert") {
		# populate appropriate autovars
		add_autovars(rules, filename)
		# if we are applying a template
		if ("template" in rules) {
			print apply_template(rules, rules["template"])
			# if we are converting
		} else if("converter" in rules){
			cmd = sprintf("%s %s", rules["converter"], filename)
			while ((cmd | getline) > 0)
				print
			close(cmd)
			# else, just output the file
		} else {
			while ((getline < filename) > 0)
				print
		}
	} else if (rules["action"] == "list") {
		die("Lists are unimplemented at this time")
	} else {
		die(sprintf("Cannot parse file %s: Unknown action '%s'", filename, rules["action"]) )
	}
}
