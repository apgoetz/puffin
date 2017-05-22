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



END {

	if (HAS_DIED=="true") {
		exit -1
	}
	
	# get the rules that apply to the file we are parsing
	if (!get_rules(adt, filename, rules)) {
		get_rules(adt, filename, rules)
	}


	if (ini_str(rules,"action") == "convert") {
		# populate appropriate autovars
		add_autovars(rules, filename)
		# if we are applying a template
		if ("template" in rules) {
			print apply_template(rules, ini_str(rules,"template"))
			# if we are converting FIXME, should use render_content()
		} else if("converter" in rules){
			cmd = sprintf("%s %s", ini_str(rules,"converter"), filename)
			while ((cmd | getline) > 0)
				print
			close(cmd)
			# else, just output the file
		} else {
			while ((getline < filename) > 0)
				print
			close(filename)
		}
	} else if (ini_str(rules,"action") == "list") {
		if (ini_str(rules,"src") == "") {
			die("must specify source files for a list action")
		}
		if (!("template" in rules)) {
			die("must specify a template for a list action")
		}
		find_cmd = "find " ini_str(rules,"src") " -type f -and ! -name '" ini_str(rules,"ignore") "'"

		if (! ("sort_order" in rules)) {
			ini_add_str(rules,"sort_order", "descending")
		}
		
		num_items = 0
		# need to get the rules for each possible file in the list
		while ((find_cmd | getline) > 0) {
			split("", item_rules)
			item_filename = $0
			get_rules(adt, $0, item_rules)

			if (ini_str(item_rules,"action") != "convert") {
				die("list elements can only have the convert action")
			}

			n = split(item_filename, fileparts, ".")
			ext = fileparts[n]

			# if the source file has the wrong extension for its converter, skip it.
			if (ini_str(item_rules,"src_ext") != "" && ext != ini_str(item_rules,"src_ext")) {
				continue
			}

			add_autovars(item_rules, item_filename)
			num_items++
			item_array[num_items] = ini_ini2frag(item_rules)
			date_array[num_items] = ini_str(item_rules,"Date")
		}
		
		close(find_cmd)
		if (ini_str(rules,"sort_order") == "descending") {
			sort_desc = 1
		} else if (ini_str(rules,"sort_order") == "ascending") {
			sort_desc = 0
		} else {die(sprintf("Unknown sort order '%s'", ini_str(rules,"sort_order")))}
		sort_items(date_array, item_array, num_items, sort_desc)
		
		for (i in item_array) {
			rules[i] = item_array[i]
		}
		ini_add_str(rules,"num_Items", num_items)

		print apply_template(rules, ini_str(rules,"template"))
		
	} else {
		die(sprintf("Cannot parse file %s: Unknown action '%s'", filename, ini_str(rules,"action")) )
	}
}
