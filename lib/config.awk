# awk library to parse config file

function has_frontmatter(filename) {
	return ! system(sprintf("head -c 3 %s 2> /dev/null | grep '+++' > /dev/null 2>&1", filename)) 
}

function add_frontmatter(rules, filename,    text) {

	# check to see if the file has frontmatter
	# frontmatter has magic value +++ as first three bytes of file
	# if it doesn't have this, we can return
	if (! has_frontmatter(filename)) {
		return
	}

	text = ""
	
	# if we are here, the file has frontmatter, so we need to parse it.
	if ((getline < filename) <= 0 || $0 !~ /^\+\+\+[[:blank:]]*$/) {
		die(sprintf("Invalid frontmatter in %s: %s", filename, $0))
	}

	while (1) {
		if ((getline < filename) <= 0) {
			die(sprintf("Unterminated +++ in frontmatter in %s", filename))
		}

		if ($0 ~ /^\+\+\+[[:blank:]]*$/) {
			break
		}
		text = text "\n" $0
	}
	close(filename)
	rule2array(text,rules)
	# return number of lines in frontmatter
	return gsub("\\n", "", text) + 3
}

# each time we see a new file, store as part of rule name
FNR == 1 {
	
	# get the directory of the current file
	len_file_rule = split(FILENAME,file_rule,"/")
	delete file_rule[len_file_rule]
	len_file_rule--
	file_rule_str = join(file_rule, 1, len_file_rule, "/")
	cur_rule_str = file_rule_str

	# special case: we get passed in the default rules.
	# we set these rules in the global scope
	if (FILENAME == (puf_lib "/puffin.ini")) {
		file_rule_str = "."
		cur_rule_str = "."
	}
}


# if we are in find_sec look for things that match brackets

# remove comment lines
/^[:space:]*#/ {next}

#change rule based on new section encountered
match($0, /\[.*\]/) {
	rulename = substr($0, RSTART+1, RLENGTH-2)
	cur_rule_str = file_rule_str "/" rulename
}

# if we detect a setting of a key value
/.*=.*/ {
	if (cur_rule_str in adt)
		adt[cur_rule_str] = adt[cur_rule_str] "\n" $0
	else
		adt[cur_rule_str] = $0
}
