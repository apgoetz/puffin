# render an output file based on commands in the adt

function get_abmon_arr(abmon_arr,    tmp_arr, i) {
	cmd = "locale abmon"
	if ((cmd | getline) <= 0) {
		die("Error calling locale function")
	}
	split($0,tmp_arr, ";")
	for (i in tmp_arr) {
		abmon_arr[tmp_arr[i]] = i
	}
}

# populates date if necessary
function add_date(rules, filepath,     year, month, day, cmd, abmon_arr, field_arr) {
	if (! ("Date" in rules) || rules["Date"] == "") {
		# need to use ls -l because this is the only POSIX way to get time modified
		cmd = "ls -l " filepath
		cmd | getline
		close(cmd)
		month = $6
		day = $7
		if ($8 ~ /:/) {
			cmd = "date +%Y"
			cmd | getline
			close(cmd)
			year = $0
		} else {
			year = $8
		}

		# convert month string to number
		get_abmon_arr(abmon_arr)
		rules["Date"] = sprintf("%d-%02d-%02d",year,abmon_arr[month],day)
	}
	parse_iso8601(rules["Date"],field_arr)
	rules["DateFields"] = array2rule(field_arr)
}

function add_autovars(rules, filepath,     n, fileparts, filename, ext, words, i, basepath) {
	n = split(filepath, fileparts, "/")
	filename = fileparts[n]
	n = split(filename, fileparts, ".")
	ext = fileparts[n] # populate extension

	rules["filename"] = filepath
	
	# populate title if not set
	if (! ("Title" in rules)) {
		n = split(fileparts[1], words, /[ \-_]/)
		for (i in words) {
			words[i] = toupper(substr(words[i], 1, 1)) substr(words[i], 2)
		}
		rules["Title"] = join(words, 1, n, " ")
	}

	# populate date
	add_date(rules, filepath)

	# populate permalink
	if (! ("Permalink" in rules)) {
		basepath = get_basepath(rules, filepath)
		n = split(basepath, fileparts, ".")
		rules["Permalink"] = "/" join(fileparts, 1, n-1, ".")
		if (ext == rules["src_ext"]) {
			rules["Permalink"] = rules["Permalink"] "." rules["dest_ext"]
		} else {
			rules["Permalink"] = rules["Permalink"] "." ext
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
			close(filename)
		}
	} else if (rules["action"] == "list") {
		die("Lists are unimplemented at this time")
	} else {
		die(sprintf("Cannot parse file %s: Unknown action '%s'", filename, rules["action"]) )
	}
}
