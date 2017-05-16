# render an output file based on commands in the adt

# helper func to sort list of items
function sort_items(dates, items, n_elems, sort_desc,    i, j, tmp) {
	for (i = 2; i <= n_elems; i++) {
		j = i
		if (!sort_desc) {
			while (j > 1 && dates[j-1] > dates[j]) {
				tmp = dates[j]
				dates[j] = dates[j-1]
				dates[j-1] = tmp
				tmp = items[j]
				items[j] = items[j-1]
				items[j-1] = tmp
				j--
			}
		} else {
			while (j > 1 && dates[j-1] < dates[j]) {
				tmp = dates[j]
				dates[j] = dates[j-1]
				dates[j-1] = tmp
				tmp = items[j]
				items[j] = items[j-1]
				items[j-1] = tmp
				j--
			}
		}
	}
}


function get_abmon_arr(abmon_arr,    tmp_arr, i) {
	cmd = "locale abmon"
	if ((cmd | getline) <= 0) {
		die("Error calling locale function")
	}
	close(cmd)
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

function add_pubdate(rules,   cmd) {
	if (! ("PubDate" in rules)) {
		cmd = "date +%Y-%m-%dT%T"
		if ((cmd | getline) <= 0) {
			die("Could not get current time")
		}
		close(cmd)
		rules["PubDate"] = $0
	}
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

	add_pubdate(rules)
	
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
			# if we are converting FIXME, should use render_content()
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
		if (rules["src"] == "") {
			die("must specify source files for a list action")
		}
		if (!("template" in rules)) {
			die("must specify a template for a list action")
		}
		find_cmd = "find " rules["src"] " -type f -and ! -name '" rules["ignore"] "'"

		if (! ("sort_order" in rules)) {
			rules["sort_order"] = "descending"
		}
		
		num_items = 0
		# need to get the rules for each possible file in the list
		while ((find_cmd | getline) > 0) {
			item_filename = $0
			get_rules(adt, $0, item_rules)

			if (item_rules["action"] != "convert") {
				die("list elements can only have the convert action")
			}

			n = split(item_filename, fileparts, ".")
			ext = fileparts[n]

			# if the source file has the wrong extension for its converter, skip it.
			if (item_rules["src_ext"] != "" && ext != item_rules["src_ext"]) {
				continue
			}

			add_autovars(item_rules, item_filename)
			num_items++
			item_array[num_items] = array2rule(item_rules)
			date_array[num_items] = item_rules["Date"]
		}
		
		close(find_cmd)
		if (rules["sort_order"] == "descending") {
			sort_desc = 1
		} else if (rules["sort_order"] == "ascending") {
			sort_desc = 0
		} else {die(sprintf("Unknown sort order '%s'", rules["sort_order"]))}
		sort_items(date_array, item_array, num_items, sort_desc)
		
		for (i in item_array) {
			rules[i] = item_array[i]
		}
		rules["num_Items"] = num_items
		print apply_template(rules, rules["template"])
		
	} else {
		die(sprintf("Cannot parse file %s: Unknown action '%s'", filename, rules["action"]) )
	}
}
